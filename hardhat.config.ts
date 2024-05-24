import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import "hardhat-gas-reporter";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-ethers";
import loadEnv from "dotenv";

loadEnv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true" ? true : false,
    currency: "USD",
    coinmarketcap: process.env.CMC_API_KEY,
    outputJSON: true,
    outputJSONFile: "gas-report.json",
  },
};

export default config;
