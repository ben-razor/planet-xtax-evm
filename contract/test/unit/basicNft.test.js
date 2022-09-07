// We are going to skimp a bit on these tests...

const { assert } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
? describe.skip
: describe("Basic NFT Unit Tests", function () {
    let basicNft, deployer

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["basicnft"])
        basicNft = await ethers.getContract("BasicNft")
    })

    describe("Construtor", () => {
        it("Initilizes the NFT Correctly.", async () => {
            const name = await basicNft.name()
            const symbol = await basicNft.symbol()
            const tokenCounter=await basicNft.getTokenCounter()
            assert.equal(name, "Planet XtaX")
            assert.equal(symbol, "XTAX")
            assert.equal(tokenCounter.toString(),"0")
        })
    })

    describe("Mint NFT", () => {
        it("Allows users to mint an NFT, and updates appropriately", async function () {
            const txResponse = await basicNft.mintNft()
            await txResponse.wait(1)
            const tokenURI = await basicNft.tokenURI(0)
            const tokenCounter = await basicNft.getTokenCounter()

            assert.equal(tokenCounter.toString(), "1")
            assert.equal(tokenURI, await basicNft.TOKEN_URI())
        })
    })

    describe("Verify Sig", () => {
        it("verifies signatures", async function () {
            const h = Buffer.from('2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824', 'hex')
            const s = Buffer.from('6eecc89379e1f096c6cf1f195ae78c4cc483a4568c560ae7ade097ee83d34305650a3c224ba60bf04056ebb3520110578aeb80dfc93507f009a1b925ca81db29', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'

            const res = await basicNft.recover(h, s)

            assert.equal(res, a)
        })
    })

    describe("Planet", () => {
        it("mints planets", async function () {
            const s = Buffer.from('897e5e9732a97ab5d4d0467197a2b8e22e5c0e516bdd77bfc8fb8a79f331453a374bf032807d25859a0f191292f42a25d2ff3523fa0f2b7d75249d198f05d8761c', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            let ar = await basicNft.mintPlanet("a", "b", "c", s)
            assert.equal(ar, a)
        })
    });
});
