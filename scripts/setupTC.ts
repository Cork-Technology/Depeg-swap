import hre from "hardhat";
import dotenv from "dotenv";

import * as TC from "../ignition/modules/TC";
import { parseEther } from "viem";

dotenv.config();

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
  console.log("CETH deployed to     :", ceth.address);

  await ceth.write.mint([
    deployer.account.address,
    parseEther("100000000000000"),
  ]);
  console.log(
    "100 Trillion CETH Minted to deployer     :",
    deployer.account.address
  );

  let { cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Bear Sterns Restaked Eth",
        symbol: "bsETH,",
        ceth: "0xDe6CCd057e10A5Fa5B33fd97031Afa806586db32",
        admin: deployer.account.address,
      },
    },
  });
  console.log("bsETH deployed to       :", cst.address);

  ({ cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Lehman Brothers Restaked ETH",
        symbol: "lbETH,",
        ceth: "0xDe6CCd057e10A5Fa5B33fd97031Afa806586db32",
        admin: deployer.account.address,
      },
    },
  }));
  console.log("lbETH deployed to       :", cst.address);

  ({ cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Washington Mutual restaked ETH",
        symbol: "wamuETH,",
        ceth: "0xDe6CCd057e10A5Fa5B33fd97031Afa806586db32",
        admin: deployer.account.address,
      },
    },
  }));
  console.log("wamuETH deployed to       :", cst.address);

  ({ cst } = await hre.ignition.deploy(TC.cst, {
    parameters: {
      CST: {
        name: "Merrill Lynch staked ETH",
        symbol: "mlETH,",
        ceth: "0xDe6CCd057e10A5Fa5B33fd97031Afa806586db32",
        admin: deployer.account.address,
      },
    },
  }));
  console.log("mlETH deployed to       :", cst.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
  });
