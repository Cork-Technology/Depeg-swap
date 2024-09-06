import hre from "hardhat";
import dotenv from "dotenv";

import * as TC from "../ignition/modules/TC";
import { parseEther } from "viem";

dotenv.config();

const depositAmount = parseEther("1000000000000");

async function inferDeployer() {
  const deployer = await hre.viem.getWalletClients();
  const pk = process.env.PRIVATE_KEY!;

  return { deployer: deployer[0], pk };
}

async function main() {
  const { deployer, pk } = await inferDeployer();

  console.log("PRODUCTION                   :", process.env.PRODUCTION);
  console.log("Network                      :", hre.network.name);
  console.log("Chain Id                     :", hre.network.config.chainId);
  console.log("Deployer                     :", deployer.account.address);
  console.log("");

  const { ceth } = await hre.ignition.deploy(TC.ceth);
  console.log("CETH deployed to          :", ceth.address);

  await ceth.write.mint([
    deployer.account.address,
    parseEther("100000000000000"),
  ]);
  console.log("100 Trillion CETH Minted");

  let { cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Bear Sterns Restaked Eth",
        symbol: "bsETH",
        ceth: ceth.address,
        admin: deployer.account.address,
      },
    },
  });
  console.log("bsETH deployed to         :", cst.address);
  ceth.write.approve([cst.address, depositAmount]);
  cst.write.deposit([depositAmount]);
  console.log("1 Trillion bsETH Minted");

  ({ cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Lehman Brothers Restaked ETH",
        symbol: "lbETH",
        ceth: ceth.address,
        admin: deployer.account.address,
      },
    },
  }));
  console.log("lbETH deployed to         :", cst.address);
  ceth.write.approve([cst.address, depositAmount]);
  cst.write.deposit([depositAmount]);
  console.log("1 Trillion lbETH Minted");

  ({ cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Washington Mutual restaked ETH",
        symbol: "wamuETH",
        ceth: ceth.address,
        admin: deployer.account.address,
      },
    },
  }));
  console.log("wamuETH deployed to       :", cst.address);
  ceth.write.approve([cst.address, depositAmount]);
  cst.write.deposit([depositAmount]);
  console.log("1 Trillion wamuETH Minted");

  ({ cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Merrill Lynch staked ETH",
        symbol: "mlETH",
        ceth: ceth.address,
        admin: deployer.account.address,
      },
    },
  }));
  console.log("mlETH deployed to         :", cst.address);
  ceth.write.approve([cst.address, depositAmount]);
  cst.write.deposit([depositAmount]);
  console.log("1 Trillion mlETH Minted");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
  });
