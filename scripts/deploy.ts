import hre from "hardhat";
import dotenv from "dotenv";

import * as core from "../ignition/modules/core";
import * as lib from "../ignition/modules/lib";
import * as uniV2 from "../ignition/modules/uniV2";
import { isAddress } from "viem";

dotenv.config();

function inferWeth() {
  const weth = process.env.WETH;

  if (process.env.PRODUCTION?.toLowerCase() == "true") {
    if (weth == undefined || weth == "") {
      throw new Error("WETH address not provided");
    }

    if (isAddress(weth)) {
      throw new Error("Invalid WETH address");
    }

    console.log("using WETH address from env:", weth);

    return weth;
  }

  return weth;
}

async function main() {
  console.log("PRODUCTION                   :", process.env.PRODUCTION);
  console.log("Network                      :", hre.network.name);
  console.log("Chain Id                     :", hre.network.config.chainId);
  console.log("")

  const weth =
    inferWeth() ??
    (await hre.ignition.deploy(uniV2.dummyWETH)).DummyWETH.address;

  const { assetFactory } = await hre.ignition.deploy(core.assetFactory);
  const { CorkConfig } = await hre.ignition.deploy(core.corkConfig);
  const { FlashSwapRouter } = await hre.ignition.deploy(core.flashSwapRouter);
  const { UniV2Factory } = await hre.ignition.deploy(uniV2.uniV2Factory, {
    parameters: {
      uniV2Factory: { flashSwapRouter: FlashSwapRouter.address },
    },
  });
  const { UniV2Router } = await hre.ignition.deploy(uniV2.uniV2router, {
    parameters: {
      UniV2Router: {
        weth,
        flashSwapRouter: FlashSwapRouter.address,
        uniV2Factory: UniV2Factory.address,
      },
    },
  });

  const { ModuleCore } = await hre.ignition.deploy(core.ModuleCore, {
    parameters: {
      ModuleCore: {
        assetFactory: assetFactory.address,
        uniV2Factory: UniV2Factory.address,
        flashSwapRouter: FlashSwapRouter.address,
        uniV2Router: UniV2Router.address,
        corkConfig: CorkConfig.address,
      },
    },
  });

  await assetFactory.write.initialize([ModuleCore.address]);

  console.log("ModuleCore deployed to       :", ModuleCore.address);
  console.log("AssetFactory deployed to     :", assetFactory.address);
  console.log("CorkConfig deployed to       :", CorkConfig.address);
  console.log("FlashSwapRouter deployed to  :", FlashSwapRouter.address);
  console.log("UniV2Factory deployed to     :", UniV2Factory.address);
  console.log("UniV2Router deployed to      :", UniV2Router.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
  });
