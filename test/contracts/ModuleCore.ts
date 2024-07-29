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
    const { defaultSigner } = await helper.getSigners();

    const mathLib = await hre.viem.deployContract("MathHelper");

    const dsFlashSwapRouter = await helper.deployFlashSwapRouter();
    const univ2Factory = await helper.deployUniV2Factory();
    const weth = await helper.deployWeth();
    const univ2Router = await helper.deployUniV2Router(
      weth.contract.address,
      univ2Factory,
      dsFlashSwapRouter.contract.address
    );
    const swapAssetFactory = await helper.deployAssetFactory();
    const config = await helper.deployCorkConfig();

    const contract = await hre.viem.deployContract(
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
        },
      }
    );

    expect(contract).to.be.ok;
  });
});
