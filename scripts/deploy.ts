import hre from "hardhat";
import dotenv from "dotenv";

import * as core from "../ignition/modules/core";
import * as lib from "../ignition/modules/lib";
import * as uniV2 from "../ignition/modules/uniV2";
import UNIV2FACTORY from "../test/helper/ext-abi/uni-v2-factory.json";
import UNIV2ROUTER from "../test/helper/ext-abi/uni-v2-router.json";

import { Address, isAddress } from "viem";

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

function inferBaseRedemptionFee() {
  const fee = process.env.PSM_BASE_REDEMPTION_FEE_PRECENTAGE;

  if (fee == undefined || fee == "") {
    throw new Error("PSM_BASE_REDEMPTION_FEE_PRECENTAGE not provided");
  }

  return fee;
}

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

  const weth =
    inferWeth() ??
    (await hre.ignition.deploy(uniV2.dummyWETH)).DummyWETH.address;
  const baseRedemptionFee = inferBaseRedemptionFee();

  const { assetFactory } = await hre.ignition.deploy(core.assetFactory);
  console.log("AssetFactory deployed to     :", assetFactory.address);

  const { CorkConfig } = await hre.ignition.deploy(core.corkConfig);
  console.log("CorkConfig deployed to       :", CorkConfig.address);

  const { FlashSwapRouter } = await hre.ignition.deploy(core.flashSwapRouter);
  console.log("FlashSwapRouter deployed to  :", FlashSwapRouter.address);

  const UniV2Factory = await hre.deployments.deploy("uniV2Factory", {
    from: pk,
    args: [deployer.account.address, FlashSwapRouter.address],
    contract: {
      abi: UNIV2FACTORY.abi,
      bytecode: UNIV2FACTORY.evm.bytecode.object,
      deployedBytecode: UNIV2FACTORY.evm.deployedBytecode.object,
      metadata: UNIV2FACTORY.metadata,
    },
    gasLimit: 10_000_000,
  });

  console.log("UniV2Factory deployed to     :", UniV2Factory.address);

  const UniV2Router = await hre.deployments.deploy("uniV2Router", {
    from: pk,
    args: [UniV2Factory.address, weth, FlashSwapRouter.address],
    contract: {
      abi: UNIV2ROUTER.abi,
      bytecode: UNIV2ROUTER.evm.bytecode.object,
      deployedBytecode: UNIV2ROUTER.evm.deployedBytecode.object,
      metadata: UNIV2ROUTER.metadata,
    },
    gasLimit: 10_000_000,
  });

  console.log("UniV2Router deployed to      :", UniV2Router.address);

  const { ModuleCore } = await hre.ignition.deploy(core.ModuleCore, {
    parameters: {
      ModuleCore: {
        assetFactory: assetFactory.address,
        uniV2Factory: UniV2Factory.address,
        flashSwapRouter: FlashSwapRouter.address,
        uniV2Router: UniV2Router.address,
        corkConfig: CorkConfig.address,
        psmBaseFeeRedemption: baseRedemptionFee,
      },
    },
  });

  await assetFactory.write.initialize([ModuleCore.address]);
  await FlashSwapRouter.write.initialize([
    ModuleCore.address,
    UniV2Factory.address as Address,
  ]);

  console.log("ModuleCore deployed to       :", ModuleCore.address);
}

function sleep(ms: number) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
  });
