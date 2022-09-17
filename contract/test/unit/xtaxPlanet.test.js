// We are going to skimp a bit on these tests...

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
const { planets, defaultPlanets } = require('../../test/data/planet/test_planet_1')

!developmentChains.includes(network.name)
? describe.skip
: describe("XtaXPlanet Unit Tests", function () {
    let xtaxPlanet, deployer, mintValue

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["xtaxplanet"])
        xtaxPlanet = await ethers.getContract("XtaxPlanet")
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

    describe("Verify Sig", () => {
        it("verifies signatures", async function () {
            const h = Buffer.from('2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824', 'hex')
            const s = Buffer.from('6eecc89379e1f096c6cf1f195ae78c4cc483a4568c560ae7ade097ee83d34305650a3c224ba60bf04056ebb3520110578aeb80dfc93507f009a1b925ca81db29', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'

            const res = await xtaxPlanet.recover(h, s)

            assert.equal(res, a)
        })
    })

    const VALID_POSITION= ["0", "42", "0"]
    const VALID_LEVEL = VALID_POSITION[1].toString()
    const INVALID_POSITION= ["0", "1", "0"]

    describe("Planet", () => {
        it("mints planets", async function () {
            const sInvalid = Buffer.from('6389be768a57c34066221d4231e779acdd0365ab7b5ad5e62cdb959dda5943ba336977189acc806bb928ac6b20c47ecd9e12566fccde11473900346e1fc173031c', 'hex')
            const s = Buffer.from('5389be768a57c34066221d4231e779acdd0365ab7b5ad5e62cdb959dda5943ba336977189acc806bb928ac6b20c47ecd9e12566fccde11473900346e1fc173031c', 'hex')
            const sInvalidPos = Buffer.from('2ae6b3f2b94274acb43bad3f5a5dc6d10f040aaed76e6a19e5fd68dac7dbac5968f24920cfca0eeb75ba42cb9be9284d7f56002d9b926e516205861f916b73691b', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            
            await expect(
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, sInvalid, mintValue)
            ).to.be.revertedWith('VerifyFailed()')

            await xtaxPlanet.addSigner(a);

            await expect(
                xtaxPlanet.mintPlanet("a", "b", INVALID_POSITION, sInvalidPos, mintValue)
            ).to.be.revertedWith(`IncorrectLevel("${VALID_LEVEL}", "1")`)

            await expect(
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s, mintValue)
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
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s, mintValue)
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

        describe("Payable", () => {
            it("is payable", async () => {
                let acc1 = accounts[0].address
                let acc2 = accounts[1].address
                let owner, nft, recentPlanets, balance
                let acc1Balance, acc2Balance, contractBalance
                const s = Buffer.from('5389be768a57c34066221d4231e779acdd0365ab7b5ad5e62cdb959dda5943ba336977189acc806bb928ac6b20c47ecd9e12566fccde11473900346e1fc173031c', 'hex')
                const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
                await xtaxPlanet.addSigner(a)
                
                mintValueLow = {value: ethers.utils.parseEther("0.5")}
    
                contractBalance = await ethers.provider.getBalance(xtaxPlanet.address);
                expect(contractBalance).to.equal('0')
    
                acc2Balance = await ethers.provider.getBalance(accounts[2].address);
                expect(acc2Balance).to.equal(ethers.utils.parseEther("10000"))
    
                await expect(
                    xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s, mintValueLow)
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
                    xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s, mintValueLow)
                ).to.not.be.reverted
    
                /*
                contractBalance = await ethers.provider.getBalance(xtaxPlanet.address);
                expect(contractBalance).to.equal(mintValueLow.value)
    
                await expect(
                    xtaxPlanet.connect(accounts[1]).withdraw(accounts[1].address, mintValueLow.value)
                ).to.be.revertedWith('Ownable: caller is not the owner')
    
                await expect(
                    xtaxPlanet.withdraw(accounts[2].address, mintValueLow.value)
                ).to.not.be.reverted
    
                contractBalance = await ethers.provider.getBalance(xtaxPlanet.address);
                expect(contractBalance).to.equal("0")
    
                acc2Balance = await ethers.provider.getBalance(accounts[2].address);
                expect(acc2Balance).to.equal(ethers.utils.parseEther("10000.5"))
                */
    
            })
        })

        it("transfers planets", async () => {
            let acc1 = accounts[0].address
            let acc2 = accounts[1].address
            let owner, nft, recentCells, balance;

            const s = Buffer.from('5389be768a57c34066221d4231e779acdd0365ab7b5ad5e62cdb959dda5943ba336977189acc806bb928ac6b20c47ecd9e12566fccde11473900346e1fc173031c', 'hex')
            const a = '0x19E507ff3820Aac62eD624cA19Ad1F1c3d83cd2F'
            
            await xtaxPlanet.addSigner(a);

            await expect(
                xtaxPlanet.mintPlanet("a", "b", VALID_POSITION, s, mintValue)
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
