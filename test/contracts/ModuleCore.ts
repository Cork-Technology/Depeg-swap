import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("ModuleCore", function () {
  it("should deploy", async function () {
    const { defaultSigner } = helper.getSigners(
      await hre.viem.getWalletClients()
    );

    const mathLib = await hre.viem.deployContract("MathHelper");
    const vault = await hre.viem.deployContract("VaultLibrary", [], {
      libraries: {
        MathHelper: mathLib.address,
      },
    });

    const dsFlashSwapRouter = await helper.deployFlashSwapRouter(mathLib.address);
    const univ2Factory = await helper.deployUniV2Factory(dsFlashSwapRouter.contract.address);
    const weth = await helper.deployWeth();
    const univ2Router = await helper.deployUniV2Router(
      weth.contract.address,
      univ2Factory,
      dsFlashSwapRouter.contract.address
    );
    const swapAssetFactory = await helper.deployAssetFactory();
    const config = await helper.deployCorkConfig();

    const moduleCore = await hre.viem.deployContract(
      "ModuleCore",
      [
        swapAssetFactory.contract.address,
        univ2Factory,
        dsFlashSwapRouter.contract.address,
        univ2Router,
        config.contract.address,
      ],
      {
        client: {
          wallet: defaultSigner,
        },
        libraries: {
          MathHelper: mathLib.address,
          VaultLibrary: vault.address,
        },
      }
    );
    expect(moduleCore).to.be.ok;
  });
});
