// We are going to skimp a bit on these tests...

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
const { cells } = require('../data/cell/test_cells_1')

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
            const tokenCounter = await xtaxCell.getTokenCounter()
            assert.equal(name, "Planet XtaX Cell")
            assert.equal(symbol, "XTAXC")
            assert.equal(tokenCounter.toString(),"0")
        })
    })

    describe("Mint NFT", () => {
        it("Allows users to mint an NFT, and updates appropriately", async function () {
            
        })
    })

    describe("Cell", () => {
        it("mints cells", async function () {
            const s = Buffer.from('34b02f92030c8c1c4dc9bf682c8f86076bdf596cc56881884b313f04a586aaa61a057e623491378728c0bb286bc9ed95acdbee9cc8b16b5842ef25254e6194681c', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            
            await expect(
                xtaxCell.mintCell("a", s)
            ).to.be.revertedWith('VerifyFailed()')

            await xtaxCell.addSigner(a);

            await expect(
                xtaxCell.mintCell(cells[0].msg, Buffer.from(cells[0].sigHex, 'hex'))
            ).to.emit(xtaxCell, 'MintedCell')
            .withArgs(accounts[0].address, 1, cells[0].msg);

            for(let i = 1; i < 8; i++) {
                await xtaxCell.mintCell(cells[i].msg, Buffer.from(cells[i].sigHex, 'hex'))
            }

            let recentCells = await xtaxCell.recentCellsForAddress(accounts[0].address);
            console.log(JSON.stringify(recentCells));
            
            expect(recentCells[0].cellMetadataCID).to.equal(cells[7].msg)
            expect(recentCells[7].cellMetadataCID).to.equal(cells[0].msg)

            /*
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
            
            */
        })
    });
});
