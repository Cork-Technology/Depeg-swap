import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { ethers, upgrades } from "hardhat";

import { Address, formatEther, parseEther, WalletClient } from "viem";
import { getSigners } from "./helper/TestHelper";

describe("Asset Factory", function () {
  it("should deploy AssetFactory", async function () {
    const { defaultSigner } = await getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    expect(contract).to.be.ok;
  });
});
