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

    const moduleCore = await hre.viem.deployContract(
      "ModuleCore",
      [defaultSigner.account.address, defaultSigner.account.address],
      {
        client: {
          wallet: defaultSigner,
        },
        libraries: {
          MathHelper: mathLib.address,
        },
      }
    );
    expect(moduleCore).to.be.ok;
  });
});
