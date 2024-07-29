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

    const contract = await hre.viem.deployContract(
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

    expect(contract).to.be.ok;
  });
});
