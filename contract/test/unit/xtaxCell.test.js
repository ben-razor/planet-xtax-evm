// We are going to skimp a bit on these tests...

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
const { cells } = require('../data/cell/test_cells_1')

!developmentChains.includes(network.name)
? describe.skip
: describe("XtaXCell Unit Tests", function () {
    let xtaxCell, deployer, mintValue

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["xtaxcell"])
        xtaxCell = await ethers.getContract("XtaxCell")
        mintValue = {value: ethers.utils.parseEther("0.1")}
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
            let recentCells
            const s = Buffer.from('34b02f92030c8c1c4dc9bf682c8f86076bdf596cc56881884b313f04a586aaa61a057e623491378728c0bb286bc9ed95acdbee9cc8b16b5842ef25254e6194681c', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            
            await expect(
                xtaxCell.mintCell("a", s, mintValue)
            ).to.be.revertedWith('VerifyFailed()')

            await xtaxCell.addSigner(a);

            recentCells = await xtaxCell.recentCellsForAddress(accounts[0].address);
            expect(recentCells[0].cellMetadataCID).to.equal('')

            await expect(
                xtaxCell.mintCell(cells[0].msg, Buffer.from(cells[0].sigHex, 'hex'), mintValue)
            ).to.emit(xtaxCell, 'MintedCell')
            .withArgs(accounts[0].address, 1, cells[0].msg);

            for(let i = 1; i < 8; i++) {
                await xtaxCell.mintCell(cells[i].msg, Buffer.from(cells[i].sigHex, 'hex'), mintValue)
            }

            recentCells = await xtaxCell.recentCellsForAddress(accounts[0].address);
            console.log(JSON.stringify(recentCells));
            
            expect(recentCells[0].cellMetadataCID).to.equal(cells[7].msg)
            expect(recentCells[7].cellMetadataCID).to.equal(cells[0].msg)

            await xtaxCell.mintCell(cells[8].msg, Buffer.from(cells[8].sigHex, 'hex'), mintValue)

            recentCells = await xtaxCell.recentCellsForAddress(accounts[0].address);
            console.log(JSON.stringify(recentCells));
            
            expect(recentCells[0].cellMetadataCID).to.equal(cells[8].msg)
            expect(recentCells[7].cellMetadataCID).to.equal(cells[1].msg)
        })
    });

    describe("Payable", () => {
        it("is payable", async () => {
            let acc1 = accounts[0].address
            let acc2 = accounts[1].address
            let owner, nft, recentCells, balance
            let acc1Balance, acc2Balance, contractBalance

            mintValueLow = {value: ethers.utils.parseEther("0.05")}

            contractBalance = await ethers.provider.getBalance(xtaxCell.address);
            expect(contractBalance).to.equal('0')

            acc2Balance = await ethers.provider.getBalance(accounts[2].address);
            expect(acc2Balance).to.equal(ethers.utils.parseEther("10000"))

            await expect(
                xtaxCell.mintCell(cells[0].msg, Buffer.from(cells[0].sigHex, 'hex'), mintValueLow)
            ).to.be.revertedWith(`NotEnoughWei(${mintValue.value}, ${mintValueLow.value})`)

            await expect(
                xtaxCell.ownerOf(1)
            ).to.be.revertedWith('ERC721: owner query for nonexistent token')

            await expect(
                xtaxCell.connect(accounts[1]).setMintPrice(mintValueLow.value)
            ).to.be.revertedWith('Ownable: caller is not the owner')

            await expect(
                xtaxCell.setMintPrice(mintValueLow.value)
            ).to.not.be.reverted

            await expect(
                xtaxCell.mintCell(cells[0].msg, Buffer.from(cells[0].sigHex, 'hex'), mintValueLow)
            ).to.not.be.reverted

            contractBalance = await ethers.provider.getBalance(xtaxCell.address);
            expect(contractBalance).to.equal(mintValueLow.value)

            await expect(
                xtaxCell.connect(accounts[1]).withdraw(accounts[1].address, mintValueLow.value)
            ).to.be.revertedWith('Ownable: caller is not the owner')

            await expect(
                xtaxCell.withdraw(accounts[2].address, mintValueLow.value)
            ).to.not.be.reverted

            contractBalance = await ethers.provider.getBalance(xtaxCell.address);
            expect(contractBalance).to.equal("0")

            acc2Balance = await ethers.provider.getBalance(accounts[2].address);
            expect(acc2Balance).to.equal(ethers.utils.parseEther("10000.05"))

        })
    })

    describe("Transfer", () => {
        it("transfers cells", async () => {
            let acc1 = accounts[0].address
            let acc2 = accounts[1].address
            let owner, nft, recentCells, balance;

            await expect(
                xtaxCell.mintCell(cells[0].msg, Buffer.from(cells[0].sigHex, 'hex'), mintValue)
            ).to.emit(xtaxCell, 'MintedCell')
            .withArgs(accounts[0].address, 1, cells[0].msg);

            owner = await xtaxCell.ownerOf(1)
            expect(owner).to.equal(acc1)

            nft = await xtaxCell.cellNFT(1)
            expect(nft.owner).to.equal(acc1)

            await expect(
                xtaxCell.transferFrom(acc1, acc2, 1)
            ).to.emit(xtaxCell, 'Transfer')
            .withArgs(acc1, acc2, 1)
            .to.emit(xtaxCell, 'TransferredCell')
            .withArgs(acc1, acc2, 1, cells[0].cid)

            owner = await xtaxCell.ownerOf(1)
            expect(owner).to.equal(acc2)

            nft = await xtaxCell.cellNFT(1)
            expect(nft.owner).to.equal(acc2)

            recentCells = await xtaxCell.recentCellsForAddress(accounts[0].address);
            expect(recentCells[0].owner).to.equal(ethers.constants.AddressZero)
            expect(recentCells[0].cellMetadataCID).to.equal('')

            recentCells = await xtaxCell.recentCellsForAddress(accounts[1].address);
            expect(recentCells[0].owner).to.equal(acc2)
            expect(recentCells[0].cellMetadataCID).to.equal(cells[0].cid)

            await expect(
                xtaxCell.connect(accounts[1])["safeTransferFrom(address,address,uint256)"](acc2, acc1, 1)
            ).to.emit(xtaxCell, 'Transfer')
            .withArgs(acc2, acc1, 1)
            .to.emit(xtaxCell, 'TransferredCell')
            .withArgs(acc2, acc1, 1, cells[0].cid)

            await expect(
                xtaxCell.connect(accounts[0])["safeTransferFrom(address,address,uint256,bytes)"](acc1, acc2, 1, [0,1,2,3])
            ).to.emit(xtaxCell, 'Transfer')
            .withArgs(acc1, acc2, 1)
            .to.emit(xtaxCell, 'TransferredCell')
            .withArgs(acc1, acc2, 1, cells[0].cid)

            balance = await xtaxCell.balanceOf(acc1)
            expect(balance).to.equal("0")

            balance = await xtaxCell.balanceOf(acc2)
            expect(balance).to.equal("1")

        })
    })

});
