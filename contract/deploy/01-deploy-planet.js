const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const { planets, defaultPlanets } = require('../test/data/planet/test_planet_1')
console.log(JSON.stringify([planets]));

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    log("----------------------------------------------------")
    arguments = [process.env.SIGNER]
    const deployment = await deploy("XtaxPlanet", {
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    let xtaxPlanet = await ethers.getContract("XtaxPlanet")
    const name = await xtaxPlanet.name()
    console.log(JSON.stringify(['name', name]));

    const mintValue = {value: ethers.utils.parseEther("1")}

    for(let p of defaultPlanets) {
        let planet = planets[p]
        let planetInfo = planet.msg.split(':')

        let planetMetadataCID = planetInfo[0]
        let planetStructureCID = planetInfo[1]
        let position = planetInfo[2].split(',')

        let tx = await xtaxPlanet.mintPlanet(
            planetMetadataCID, planetStructureCID, position, 
            Buffer.from(planet.sigHex, 'hex'), mintValue
        )

        const receipt = await tx.wait()
        console.log(receipt.logs)
    }

    // Verify the deployment
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(deployment.address, arguments)
    }

}

module.exports.tags = ["all", "xtaxplanet", "main"]
