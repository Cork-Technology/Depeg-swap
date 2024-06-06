import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "./helper/TestHelper";

describe("ModuleCore", function () {
  it("should deploy", async function () {
    const { defaultSigner } = await helper.getSigners();
    console.log("defaultSigner", defaultSigner.account.address);

    const contract = await hre.viem.deployContract(
      "ModuleCore",
      [defaultSigner.account.address],
      {
        client: {
          wallet: defaultSigner,
        },
      }
    );

    expect(contract).to.be.ok;
  });
});
