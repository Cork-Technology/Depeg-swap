import { HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox-viem";
import "hardhat-gas-reporter";
import "@nomicfoundation/hardhat-viem";
import loadEnv from "dotenv";
import "hardhat-contract-sizer";
import chai from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);
// import "@nomicfoundation/hardhat-chai-matchers";

loadEnv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "cancun",
    },
  },
  networks: {
    hardhat: {},
    sepolia: {
      url: "https://rpc.sepolia.org	",
      chainId: 1337,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true" ? true : false,
    currency: "USD",
    coinmarketcap: process.env.CMC_API_KEY,
    outputJSON: true,
    outputJSONFile: "gas-report.json",
    includeIntrinsicGas: true,
  },
  contractSizer: {
    runOnCompile: true,
    only: [
      "ModuleCore",
      "AssetFactory",
      "MathHelper",
      "VaultLibrary",
      "PsmLibrary",
      "RouterState",
    ],
  },
};

export default config;
