// We are going to skimp a bit on these tests...

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
? describe.skip
: describe("XtaXPlanet Unit Tests", function () {
    let xtaxPlanet, deployer

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["xtaxplanet"])
        xtaxPlanet = await ethers.getContract("XtaxPlanet")
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

    describe("Verify Sig", () => {
        it("verifies signatures", async function () {
            const h = Buffer.from('2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824', 'hex')
            const s = Buffer.from('6eecc89379e1f096c6cf1f195ae78c4cc483a4568c560ae7ade097ee83d34305650a3c224ba60bf04056ebb3520110578aeb80dfc93507f009a1b925ca81db29', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'

            const res = await xtaxPlanet.recover(h, s)

            assert.equal(res, a)
        })
    })

    const VALID_POSITION= ["0", "0", "0"]
    const INVALID_POSITION= ["0", "1", "0"]

    describe("Planet", () => {
        it("mints planets", async function () {
            const s = Buffer.from('34b02f92030c8c1c4dc9bf682c8f86076bdf596cc56881884b313f04a586aaa61a057e623491378728c0bb286bc9ed95acdbee9cc8b16b5842ef25254e6194681c', 'hex')
            const sInvalidPos = Buffer.from('2ae6b3f2b94274acb43bad3f5a5dc6d10f040aaed76e6a19e5fd68dac7dbac5968f24920cfca0eeb75ba42cb9be9284d7f56002d9b926e516205861f916b73691b', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            
            await expect(
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s)
            ).to.be.revertedWith('VerifyFailed()')

            await xtaxPlanet.addSigner(a);

            await expect(
                xtaxPlanet.mintPlanet("a", "b", INVALID_POSITION, sInvalidPos)
            ).to.be.revertedWith('IncorrectLevel("1", "0")')

            await expect(
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s)
            ).to.emit(xtaxPlanet, 'MintedPlanet')
            .withArgs(accounts[0].address, "1", "a");

            let owner = await xtaxPlanet.ownerOf(1);
            expect(owner).to.equal(accounts[0].address)

            await expect(
                xtaxPlanet.ownerOf(2)
            ).to.be.revertedWith('ERC721: owner query for nonexistent token')

            let planetNFT= await xtaxPlanet.planetNFT(1);
            expect(planetNFT.owner).to.equal(accounts[0].address)
            expect(planetNFT.position).to.equal(VALID_POSITION.join(','))
            expect(planetNFT.planetMetadataCID).to.equal("a")
            expect(planetNFT.planetStructureCID).to.equal("b")

            let tokenURI = await xtaxPlanet.tokenURI(1)
            assert.equal(tokenURI, 'ipfs://' + "a")
            let tokenCounter = await xtaxPlanet.getTokenCounter()
            assert.equal(tokenCounter.toString(), "1")

            let recentTokens = await xtaxPlanet.recentPlanetsForAddress(accounts[0].address);
            expect(recentTokens[0].planetMetadataCID).to.equal('a')
            expect(recentTokens).to.have.length(8);

            // Minting planet in same location by same user burns old and mints a new one
            await expect(
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s)
            ).to.emit(xtaxPlanet, 'MintedPlanet')
            .withArgs(accounts[0].address, "2", "a");

            await expect(
                xtaxPlanet.tokenURI(1)
            ).to.be.revertedWith('PlanetNotFound()')

            tokenCounter = await xtaxPlanet.getTokenCounter()
            assert.equal(tokenCounter.toString(), "2")

            planetNFT= await xtaxPlanet.planetNFT(2);
            expect(planetNFT.owner).to.equal(accounts[0].address)
            expect(planetNFT.position).to.equal(VALID_POSITION.join(','))
            expect(planetNFT.planetMetadataCID).to.equal("a")
            expect(planetNFT.planetStructureCID).to.equal("b")
            
            recentTokens = await xtaxPlanet.recentPlanetsForAddress(accounts[0].address);
            expect(recentTokens[0].planetMetadataCID).to.equal('a')
            expect(recentTokens[1].planetMetadataCID).to.equal('')

        })

        it("transfers planets", async () => {
            let acc1 = accounts[0].address
            let acc2 = accounts[1].address
            let owner, nft, recentCells, balance;

            const s = Buffer.from('34b02f92030c8c1c4dc9bf682c8f86076bdf596cc56881884b313f04a586aaa61a057e623491378728c0bb286bc9ed95acdbee9cc8b16b5842ef25254e6194681c', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            
            await xtaxPlanet.addSigner(a);

            await expect(
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s)
            ).to.emit(xtaxPlanet, 'MintedPlanet')
            .withArgs(accounts[0].address, "1", "a");

            await expect(
                xtaxPlanet.transferFrom(acc1, acc2, 1)
            ).to.emit(xtaxPlanet, 'Transfer')
            .withArgs(acc1, acc2, 1)
            .to.emit(xtaxPlanet, 'TransferredPlanet')
            .withArgs(acc1, acc2, 1, "a")

            owner = await xtaxPlanet.ownerOf(1)
            expect(owner).to.equal(acc2)

            nft = await xtaxPlanet.planetNFT(1)
            expect(nft.owner).to.equal(acc2)

            recentPlanets = await xtaxPlanet.recentPlanetsForAddress(accounts[0].address);
            expect(recentPlanets[0].owner).to.equal(ethers.constants.AddressZero)
            expect(recentPlanets[0].planetMetadataCID).to.equal('')


        })
    });
});
