import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("wrapped asset", function () {
  // @yusak found this bug, causes explorer to fail to display the decimals
  it("should get correct decimals", async function () {
    const { defaultSigner } = await helper.getSigners();
    const { contract: factory } = await helper.deployAssetFactory();

    await factory.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    const { ra } = await helper.backedAssets();

    const asset = await helper.createWa({
      factory: factory.address,
      ra: ra.address,
    });

    const wrappedAsset = await hre.viem.getContractAt("WrappedAsset", asset!);

    const decimals = await wrappedAsset.read.decimals();

    expect(decimals).to.equal(18);
  });
});
