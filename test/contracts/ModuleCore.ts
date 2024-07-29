import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("ModuleCore", function () {
  let primarySigner: any;
  let secondSigner: any;

  let mathLib: any;
  let moduleCore: any;

  before(async () => {
    const { defaultSigner, signers } = await helper.getSigners();
    primarySigner = defaultSigner;
    secondSigner = signers[1];
  });

  beforeEach(async () => {
    mathLib = await hre.viem.deployContract("MathHelper");

    moduleCore = await hre.viem.deployContract(
      "ModuleCore",
      [primarySigner.account.address, primarySigner.account.address],
      {
        client: {
          wallet: primarySigner,
        },
        libraries: {
          MathHelper: mathLib.address,
        },
      }
    );
  });

  it("should deploy", async function () {
    expect(moduleCore).to.be.ok;
  });
});
