require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.33",
  networks: {
    hela: {
      url: "https://testnet-rpc.helachain.com",
      chainId: 666888,
      accounts: [process.env.HELA_PRIVATE_KEY_DEPLOY_ACCOUNT],
    },
  },
  etherscan: {
    apiKey: {
      hela: "no-api-key-needed",
    },
    customChains: [
      {
        network: "hela",
        chainId: 666888,
        urls: {
          apiURL: "https://testnet.helascan.io/api",
          browserURL: "https://testnet.helascan.io",
        },
      },
    ],
  },
};
