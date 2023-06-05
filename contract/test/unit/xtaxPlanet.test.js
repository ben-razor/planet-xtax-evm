// We are going to skimp a bit on these tests...

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
const { planets, defaultPlanets } = require('../../test/data/planet/test_planet_1')
const { testPlanets } = require('../../test/data/planet/test_planet_2')

!developmentChains.includes(network.name)
? describe.skip
: describe("XtaXPlanet Unit Tests", function () {
    let xtaxPlanet, deployer, mintValue

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["xtaxplanet"])
        xtaxPlanet = await ethers.getContract("XtaxPlanet")
        xtaxPlanet.connect(accounts[0])
        mintValue = {value: ethers.utils.parseEther("1")}
    })

    describe("Construtor", () => {
        it("Initilizes the NFT Correctly.", async () => {
            const name = await xtaxPlanet.name()
            const symbol = await xtaxPlanet.symbol()
            const tokenCounter=await xtaxPlanet.getTokenCounter()
            assert.equal(name, "Planet XtaX Planet")
            assert.equal(symbol, "XTAX")
            assert.equal(tokenCounter.toString(),"0")
        })
    })

    describe("Mint NFT", () => {
        it("Allows users to mint an NFT, and updates appropriately", async function () {
            
        })
    })

    const VALID_POSITION = ["0", "42", "0"]
    const VALID_POSITION_PRICE_LOW = ["10", "42", "10"]
    const VALID_LEVEL = VALID_POSITION[1].toString()
    const INVALID_POSITION= ["0", "1", "0"]

    describe("Planet", () => {
        it("mints planets", async function () {
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            const tp3 = testPlanets.testPlanet3
            const tp4 = testPlanets.testPlanet4
            const sig = Buffer.from(tp4.sigHex, 'hex')
            const sigInvalid = Buffer.from(tp3.sigHex, 'hex')
            const cid = tp4.cid
            const structureCID = tp4.msg.split(':')[1]
            const pos = tp4.msg.split(':')[2].split(',')
                
            await expect(
                xtaxPlanet.mintPlanet(cid, structureCID, pos, sigInvalid, mintValue)
            ).to.be.revertedWith('VerifyFailed()')

            await xtaxPlanet.addSigner(a);

            await expect(
                xtaxPlanet.mintPlanet(cid, structureCID, INVALID_POSITION, sig, mintValue)
            ).to.be.revertedWith(`IncorrectLevel("${VALID_LEVEL}", "1")`)

            console.log(accounts[0].address)
            await expect(
                xtaxPlanet.mintPlanet(cid, structureCID, pos, sig, mintValue)
            ).to.emit(xtaxPlanet, 'MintedPlanet')
            .withArgs(accounts[0].address, "1", cid);

            let owner = await xtaxPlanet.ownerOf(1);
            expect(owner).to.equal(accounts[0].address)

            await expect(
                xtaxPlanet.ownerOf(2)
            ).to.be.revertedWith('ERC721: owner query for nonexistent token')

            let planetNFT= await xtaxPlanet.planetNFT(1);
            expect(planetNFT.owner).to.equal(accounts[0].address)
            expect(planetNFT.position).to.equal(VALID_POSITION_PRICE_LOW.join(','))
            expect(planetNFT.planetMetadataCID).to.equal(cid)
            expect(planetNFT.planetStructureCID).to.equal(structureCID)

            let tokenURI = await xtaxPlanet.tokenURI(1)
            assert.equal(tokenURI, 'ipfs://' + cid)
            let tokenCounter = await xtaxPlanet.getTokenCounter()
            assert.equal(tokenCounter.toString(), "1")

            let recentTokens = await xtaxPlanet.recentPlanetsForAddress(accounts[0].address);
            expect(recentTokens[0].planetMetadataCID).to.equal(cid)
            expect(recentTokens).to.have.length(8);

            // Minting planet in same location by same user burns old and mints a new one
            await expect(
                xtaxPlanet.mintPlanet(cid, structureCID, VALID_POSITION_PRICE_LOW, sig, mintValue)
            ).to.emit(xtaxPlanet, 'MintedPlanet')
            .withArgs(accounts[0].address, "2", cid);

            await expect(
                xtaxPlanet.tokenURI(1)
            ).to.be.revertedWith('PlanetNotFound()')

            tokenCounter = await xtaxPlanet.getTokenCounter()
            assert.equal(tokenCounter.toString(), "2")

            planetNFT= await xtaxPlanet.planetNFT(2);
            expect(planetNFT.owner).to.equal(accounts[0].address)
            expect(planetNFT.position).to.equal(VALID_POSITION_PRICE_LOW.join(','))
            expect(planetNFT.planetMetadataCID).to.equal(cid)
            expect(planetNFT.planetStructureCID).to.equal(structureCID)
            
            recentTokens = await xtaxPlanet.recentPlanetsForAddress(accounts[0].address);
            expect(recentTokens[0].planetMetadataCID).to.equal(cid)
            expect(recentTokens[1].planetMetadataCID).to.equal('')

        })

        describe("Payable", () => {
            it("is payable", async () => {

                const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
                await xtaxPlanet.addSigner(a)

                const tp3 = testPlanets.testPlanet3
                const tp4 = testPlanets.testPlanet4
                const sig = Buffer.from(tp4.sigHex, 'hex')
                const sigInvalid = Buffer.from(tp3.sigHex, 'hex')
                const cid = tp4.cid
                const structureCID = tp4.msg.split(':')[1]
                const pos = tp4.msg.split(':')[2].split(',')
                
                mintValueLow = {value: ethers.utils.parseEther("0.5")}
    
                contractBalance = await ethers.provider.getBalance(xtaxPlanet.address);
                expect(contractBalance).to.equal('0')
    
                acc2Balance = await ethers.provider.getBalance(accounts[2].address);
                expect(acc2Balance).to.equal(ethers.utils.parseEther("10000"))
    
                await expect(
                    xtaxPlanet.mintPlanet(cid, structureCID, pos, sig, mintValueLow)
                ).to.be.revertedWith(`NotEnoughWei(${mintValue.value}, ${mintValueLow.value})`)
    
                await expect(
                    xtaxPlanet.ownerOf(1)
                ).to.be.revertedWith('ERC721: owner query for nonexistent token')
    
                await expect(
                    xtaxPlanet.connect(accounts[1]).setMintPrice(mintValueLow.value)
                ).to.be.revertedWith('Ownable: caller is not the owner')
    
                await expect(
                    xtaxPlanet.setMintPrice(mintValueLow.value)
                ).to.not.be.reverted
    
                await expect(
                    xtaxPlanet.mintPlanet(cid, structureCID, pos, sig, mintValueLow)
                ).to.not.be.reverted
            })
        })

        it("transfers planets", async () => {
            let acc1 = accounts[0].address
            let acc2 = accounts[1].address
            let owner, nft

            const signer = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            const tp4 = testPlanets.testPlanet4
            const sig = Buffer.from(tp4.sigHex, 'hex')
            const cid = tp4.cid
            const structureCID = tp4.msg.split(':')[1]
            const pos = tp4.msg.split(':')[2].split(',')
            
            await xtaxPlanet.addSigner(signer);

            await expect(
                xtaxPlanet.mintPlanet(cid, structureCID, pos, sig, mintValue)
            ).to.emit(xtaxPlanet, 'MintedPlanet')
            .withArgs(accounts[0].address, "1", cid);

            await expect(
                xtaxPlanet.transferFrom(acc1, acc2, 1)
            ).to.emit(xtaxPlanet, 'Transfer')
            .withArgs(acc1, acc2, 1)
            .to.emit(xtaxPlanet, 'TransferredPlanet')
            .withArgs(acc1, acc2, 1, cid)

            owner = await xtaxPlanet.ownerOf(1)
            expect(owner).to.equal(acc2)

            nft = await xtaxPlanet.planetNFT(1)
            expect(nft.owner).to.equal(acc2)

            recentPlanets = await xtaxPlanet.recentPlanetsForAddress(accounts[0].address);
            expect(recentPlanets[0].owner).to.equal(ethers.constants.AddressZero)
            expect(recentPlanets[0].planetMetadataCID).to.equal('')
        })

        it('mints real planets', async () => {
            const mintValue = {value: ethers.utils.parseEther("1")}
        
            for(let p of defaultPlanets) {
                let planet = planets[p]
                let planetInfo = planet.msg.split(':')
        
                let planetMetadataCID = planetInfo[0]
                let planetStructureCID = planetInfo[1]
                let position = planetInfo[2].split(',')
        
                await expect(
                    xtaxPlanet.mintPlanet(
                        planetMetadataCID, planetStructureCID, position, 
                        Buffer.from(planet.sigHex, 'hex'), mintValue
                    )
                ).to.emit(xtaxPlanet, 'MintedPlanet')
            }
        })
    });
});
