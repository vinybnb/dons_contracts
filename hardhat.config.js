require("@nomicfoundation/hardhat-toolbox");
const dotenv = require('dotenv')
dotenv.config()

const {  PRIVATE_KEY } = process.env;
module.exports = {
  solidity: "0.8.19",
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
    },
    testnet: {
      url: "https://bsc-testnet.blockpi.network/v1/rpc/public",
      chainId: 97,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    mainnet: {
      url: "https://rpc.ankr.com/bsc",
      chainId: 56,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    rinkeby: {
      url: "https://speedy-nodes-nyc.moralis.io/3ff17d7d4b11fbfa8d5cb8fc/eth/rinkeby",
      accounts: [`0x${PRIVATE_KEY}`],
    },
    matic: {
      url: "https://matic-mumbai.chainstacklabs.com/",
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: {
      bscTestnet: "MGYY3TKJVMX6D1WMSB4X34BEC1BVQ6E7F4",
      bsc: "R6VZU171DTE6QCKPFYRKFBXMTH7FV6FFKU"
    },
  }
};
