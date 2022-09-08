// We are going to skimp a bit on these tests...

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
? describe.skip
: describe("XtaXCell Unit Tests", function () {
    let xtaxCell, deployer

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["xtaxcell"])
        xtaxCell = await ethers.getContract("XtaxCell")
    })

    describe("Construtor", () => {
        it("Initilizes the NFT Correctly.", async () => {
            const name = await xtaxCell.name()
            const symbol = await xtaxCell.symbol()
            const tokenCounter=await xtaxCell.getTokenCounter()
            assert.equal(name, "Cell XtaX")
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

            const res = await xtaxCell.recover(h, s)

            assert.equal(res, a)
        })
    })

    const VALID_POSITION= ["0", "0", "0"]
    const INVALID_POSITION= ["0", "1", "0"]

    describe("Cell", () => {
        it("mints cells", async function () {
            const s = Buffer.from('34b02f92030c8c1c4dc9bf682c8f86076bdf596cc56881884b313f04a586aaa61a057e623491378728c0bb286bc9ed95acdbee9cc8b16b5842ef25254e6194681c', 'hex')
            const sInvalidPos = Buffer.from('2ae6b3f2b94274acb43bad3f5a5dc6d10f040aaed76e6a19e5fd68dac7dbac5968f24920cfca0eeb75ba42cb9be9284d7f56002d9b926e516205861f916b73691b', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            
            await expect(
                xtaxCell.mintCell("a", "b", VALID_POSITION, s)
            ).to.be.revertedWith('VerifyFailed()')

            await xtaxCell.addSigner(a);

            await expect(
                xtaxCell.mintCell("a", "b", INVALID_POSITION, sInvalidPos)
            ).to.be.revertedWith('IncorrectLevel("1", "0")')

            await expect(
                xtaxCell.mintCell("a", "b", VALID_POSITION, s)
            ).to.emit(xtaxCell, 'MintedCell')
            .withArgs(accounts[0].address, "1", "a");

            let owner = await xtaxCell.ownerOf(1);
            expect(owner).to.equal(accounts[0].address)

            await expect(
                xtaxCell.ownerOf(2)
            ).to.be.revertedWith('ERC721: owner query for nonexistent token')

            let cellNFT= await xtaxCell.cellNFT(1);
            expect(cellNFT.owner).to.equal(accounts[0].address)
            expect(cellNFT.position).to.equal(VALID_POSITION.join(','))
            expect(cellNFT.cellMetadataCID).to.equal("a")
            expect(cellNFT.cellStructureCID).to.equal("b")

            let tokenURI = await xtaxCell.tokenURI(1)
            assert.equal(tokenURI, 'ipfs://' + "a")
            let tokenCounter = await xtaxCell.getTokenCounter()
            assert.equal(tokenCounter.toString(), "1")

            let recentTokens = await xtaxCell.recentTokenIdsForAddress(accounts[0].address);
            expect(recentTokens[0]).to.equal(1)
            expect(recentTokens).to.have.length(8);

            // Minting cell in same location by same user burns old and mints a new one
            await expect(
                xtaxCell.mintCell("a", "b", VALID_POSITION, s)
            ).to.emit(xtaxCell, 'MintedCell')
            .withArgs(accounts[0].address, "2", "a");

            await expect(
                xtaxCell.tokenURI(1)
            ).to.be.revertedWith('ERC721Metadata: URI query for nonexistent token')

            tokenCounter = await xtaxCell.getTokenCounter()
            assert.equal(tokenCounter.toString(), "2")

            cellNFT= await xtaxCell.cellNFT(2);
            expect(cellNFT.owner).to.equal(accounts[0].address)
            expect(cellNFT.position).to.equal(VALID_POSITION.join(','))
            expect(cellNFT.cellMetadataCID).to.equal("a")
            expect(cellNFT.cellStructureCID).to.equal("b")
            
            recentTokens = await xtaxCell.recentTokenIdsForAddress(accounts[0].address);
            expect(recentTokens[0]).to.equal(2)
            expect(recentTokens[1]).to.equal(0)

        })
    });
});
