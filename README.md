# Planet XtaX EVM

Planet XtaX is a **Universe Construction Apparatus** on [Evmos Blockchain](http://evmos.org).   

Demo App: https://planet-xtax.web.app/

Demo Video: https://youtu.be/msNaZwMizWI

A submission for the Evmos Momentum Hackathon.

This repository contains contracts for storing cells and planets as NFTs on Evmos.

## The Elements

#### Cells

* A cell is a cube with characteristics defined by a schema
* Information such as name and description can be stored
* Cells are stored as NFTs on Evmos
* There can only be one owner of a cell with a given set of characteristics
* Cell NFTs can be transferred and burned

#### Seed Planets

* A seed planet is a single cell
* When a seed planet is built upon. It becomes a real planet

#### Planets

* Planets are formed by joining cells together in 3D space
* There can only be one owner of a cell with a given structure
* Once a planet is owned. Only the owner can build at that location
* The owner of a planet can warp the planet to another location
* Planet NFTs can be transferred and burned

#### Galaxies

* A galaxy is a square region that contains 25 planets

#### Levels

* The level is the height of a slice of galaxies
* Different networks or 3D configurations will be stored at different levels
* Evmos Testnet is the first network
* It occupies Level 42 of the XtaX universe

## Spacetime Structure

### Space

![Universe Structure](https://raw.githubusercontent.com/ben-razor/planet-xtax-evm/main/assets/images/infographic/structure-simple-small-1.png)

Different networks will be added at different **Levels** in the Y plane.  

In future, wormholes will be used to transmit planets between **Levels** using IBC (Inter Blockchain Communication) protocols.

There is no center and there are multiple centers. The center will change over time.

You must find your own center.

### Time

The structure of planets is determined by the planet schemas active during that time period.  

Schemas will be added and removed across time leading to varied structures throughout space.  

Planets created with short lasting schemas will have higher rarity.  

## Planet Explorer

When a new planet is created it can be seached in the explorer.  

Planets in the explorer act as outposts to allow instant travel between galaxies.  

Clicking a planet takes you straight to that galaxy.  

## Tools and Platforms

* Planet XtaX runs on modern desktop web browsers
* In this version, MetaMask is needed to connect to the Evmos blockchain

## Architecture

As planets and cells are created in a client browser. A system is needed to verify the information before creating the NFT on Evmos.  

Planet XtaX uses the following architecure to achieve this:

![System Architecture](https://raw.githubusercontent.com/ben-razor/planet-xtax-evm/main/assets/images/infographic/mint-overview.png)

## Adoption

* Created galaxies provide environments for games and creative tools to be built upon
* Evmos is an open blockchain. Anybody will be able to build applications on the created Galaxies
* Creators can be rewarded when their planets are interacted with in those applications

Planet XtaX is a completely open system for everybody to interact with with minimum friction.  

It is hoped that this removal of friction and barriers will huge adoption of the XtaX Universe.

## Evmos Specific Properties

### Interoperability

* A team is working to enable IBC (Inter Blockchain Communication) from Evmos contracts
* The Planet XtaX universe is designed to take advantage of this property
* This ability to visually interact with IBC enabled blockchains will reveal the true power of IBC

### Fee Sharing Model

* The number of possible planets and cells is near limitless
* There will be many small transactions
* This compares to the few high value transactions of traditional NFT projects
* This feature is ideal to take advantage of the fee sharing model introduced by Evmos

## Future Development

* Optimisation (Only a few planets can be onscreen at present)
* Efficiency and stability improvements
* User and security testing
* Mainnet alpha release
* Simple demo applications built upon universe
* Many secret features!

## Contracts

Planet Contract (Evmos Testnet) 0x43003fD9B4d954cFB37f136aC05871DbFF42363C
Cell Contract (Evmos Testnet)   0x3b21Fdbba3380A1A2459BdFab13166117a460E3d

## Source Code

The source for the Evmos contracts can be found at https://github.com/ben-razor/planet-xtax-evm