import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { ethers, upgrades } from "hardhat";

import { Address, formatEther, parseEther, WalletClient } from "viem";

describe("Asset Factory", function () {
  it("should deploy AssetFactory", async function () {
    const assetFactory = await ethers.getContractFactory("AssetFactory");

    const assetFactoryContract = await upgrades.deployProxy(assetFactory, []);
    await assetFactoryContract.deployed();

    console.log("AssetFactory deployed to:", assetFactoryContract);
  });
});
