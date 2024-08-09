import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("Asset Factory", function () {
  let {
    defaultSigner,
    secondSigner,
    signers,
  }: ReturnType<typeof helper.getSigners> = {} as any;

  let assetFactory: Awaited<ReturnType<typeof deployFactory>>;
  
  const deployFactory = async () => {
    return await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });
  };

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, secondSigner, signers } = helper.getSigners(__signers));
  });

  beforeEach(async () => {
    assetFactory = await loadFixture(deployFactory);

    await assetFactory.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });
  });

  it("should deploy AssetFactory", async function () {
    expect(assetFactory).to.be.ok;
  });

  it("should deploy swap assets", async function () {
    const { ra, pa } = await helper.backedAssets();

    // deploy lv to signal that a pair exist
    await assetFactory.write.deployLv([
      ra.address,
      pa.address,
      defaultSigner.account.address,
    ]);

    await assetFactory.write.deploySwapAssets([
      ra.address,
      pa.address,
      defaultSigner.account.address,
      BigInt(helper.expiry(100000)),
      parseEther("1"),
    ]);

    const events = await assetFactory.getEvents.AssetDeployed({
      ra: ra.address,
    });

    expect(events.length).to.equal(1);
  });

  it("should deploy swap sassets 100x", async function () {
    const { ra, pa } = await helper.backedAssets();

    // deploy lv to signal that a pair exist
    await assetFactory.write.deployLv([
      ra.address,
      pa.address,
      defaultSigner.account.address,
    ]);

    for (let i = 0; i < 100; i++) {
      await assetFactory.write.deploySwapAssets([
        ra.address,
        pa.address,

        defaultSigner.account.address,
        BigInt(helper.expiry(100000)),
        parseEther("1"),
      ]);
    }

    const events = await assetFactory.getEvents.AssetDeployed({
      ra: ra.address,
    });

    expect(events.length).to.equal(1);
  });

  it("shoud get deployed swap assets paged", async function () {
    const { ra, pa } = await helper.backedAssets();

    // deploy lv to signal that a pair exist
    await assetFactory.write.deployLv([
      ra.address,
      pa.address,
      defaultSigner.account.address,
    ]);

    for (let i = 0; i < 20; i++) {
      await assetFactory.write.deploySwapAssets([
        ra.address,
        pa.address,
        defaultSigner.account.address,
        BigInt(helper.expiry(100000)),
        parseEther("1"),
      ]);
    }

    const assets = await assetFactory.read.getDeployedSwapAssets([
      ra.address,
      0,
      10,
    ]);

    expect(assets[0].length).to.equal(10);
    expect(assets[1].length).to.equal(10);

    const noAsset = await assetFactory.read.getDeployedSwapAssets([
      ra.address,
      7,
      10,
    ]);

    for (const asset1 of noAsset[0]) {
      expect(asset1).to.be.equal("0x0000000000000000000000000000000000000000");
    }

    for (const asset of noAsset[1]) {
      expect(asset).to.be.equal("0x0000000000000000000000000000000000000000");
    }
  });

  it("should issue check is deployed swap assets", async function () {
    const { ra, pa } = await helper.backedAssets();

    // deploy lv to signal that a pair exist
    await assetFactory.write.deployLv([
      ra.address,
      pa.address,
      defaultSigner.account.address,
    ]);

    for (let i = 0; i < 10; i++) {
      await assetFactory.write.deploySwapAssets([
        ra.address,
        pa.address,
        defaultSigner.account.address,
        BigInt(helper.expiry(100000)),
        parseEther("1"),
      ]);
    }

    const assets = await assetFactory.read.getDeployedSwapAssets([
      ra.address,
      0,
      10,
    ]);

    expect(assets[0].length).to.equal(10);
    expect(assets[1].length).to.equal(10);

    for (const asset of assets[1]) {
      const isDeployed = await assetFactory.read.isDeployed([asset]);
      expect(isDeployed).to.be.true;
    }
  });
});
