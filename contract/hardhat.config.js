require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")
require("dotenv").config()
require("solidity-coverage")
require("hardhat-deploy")
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const PRIVATE_KEY = process.env.ACCOUNT || ""
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ""

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
            // gasPrice: 130000000000,
        },
        evmos: {
            url: `https://eth.bd.evmos.org:8545`,
            accounts: [PRIVATE_KEY],
            chainId: 9001,
            blockConfirmations: 6,
        },
        tevmos: {
            url: `https://eth.bd.evmos.dev:8545`,
            accounts: [PRIVATE_KEY],
            chainId: 9000,
            blockConfirmations: 6,
        },
        rinkeby: {
            url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY_RINKEBY}`,
            accounts: [PRIVATE_KEY],
            chainId: 4,
            blockConfirmations: 6,
        },
        mumbai: {
            chainId: 80001,
            url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_MUMBAI}`,
            accounts: [`${process.env.ACCOUNT}`]
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.8.8",
                settings: {
                    optimizer: {
                    enabled: true,
                    runs: 20
                    }
                }
            },
            {
                version: "0.6.6",
            }
        ],
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
        ropsten: process.env.ETHERSCAN_API_KEY,
        rinkeby: process.env.ETHERSCAN_API_KEY,
        polygon: process.env.POLYGONSCAN_API_KEY,
        polygonMumbai: process.env.POLYGONSCAN_API_KEY
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true,
        // coinmarketcap: COINMARKETCAP_API_KEY,
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        },
    },
    mocha: {
        timeout: 200000, // 200 seconds max for running tests
    },
}
