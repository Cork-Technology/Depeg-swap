import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "@nomicfoundation/hardhat-toolbox-viem";
import "hardhat-gas-reporter";
import "@nomicfoundation/hardhat-viem";
import loadEnv from "dotenv";
import "hardhat-contract-sizer";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import "solidity-coverage";

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
      url: "https://eth-sepolia.api.onfinality.io/public",
      chainId: 11155111,
      accounts: [process.env.PRIVATE_KEY!],
      enableTransientStorage: true,
      loggingEnabled: true,
    },
  },
  ignition: {
    requiredConfirmations: 0, 
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
