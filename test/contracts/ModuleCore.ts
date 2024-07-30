import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("ModuleCore", function () {
  let defaultSigner: any;
  let secondSigner: any;
  let signers: any;

  let mathLib: any;
  let moduleCore: any;

  before(async () => {
    ({ defaultSigner, signers } = await helper.getSigners());
    secondSigner = signers[1];
  });

  beforeEach(async () => {
    mathLib = await hre.viem.deployContract("MathHelper");

    moduleCore = await hre.viem.deployContract(
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
  });

  it("should deploy", async function () {
    expect(moduleCore).to.be.ok;
  });
});
