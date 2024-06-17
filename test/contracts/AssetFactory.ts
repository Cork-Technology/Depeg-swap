import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("Asset Factory", function () {
  it("should deploy AssetFactory", async function () {
    const { defaultSigner } = await helper.getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    expect(contract).to.be.ok;
  });

  it("should deploy wrapped assets", async function () {
    const { defaultSigner } = await helper.getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    const { ra } = await helper.backedAssets();

    const asset = await contract.write.deployWrappedAsset([ra.address]);

    const events = await contract.getEvents.WrappedAssetDeployed({
      ra: ra.address,
    });

    expect(events.length).to.equal(1);
  });
  // for gas profiling
  it("should deploy wrapped assets 100x", async function () {
    const { defaultSigner } = await helper.getSigners();

    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    for (let i = 0; i < 100; i++) {
      const { ra } = await helper.backedAssets();

      const asset = await contract.write.deployWrappedAsset([ra.address]);

      const events = await contract.getEvents.WrappedAssetDeployed({
        ra: ra.address,
      });

      expect(events.length).to.equal(1);
    }
  });
  it("should get deployed wrapped assets paged", async function () {
    const { defaultSigner } = await helper.getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    for (let i = 0; i < 20; i++) {
      const { ra } = await helper.backedAssets();

      const asset = await contract.write.deployWrappedAsset([ra.address]);

      const events = await contract.getEvents.WrappedAssetDeployed({
        ra: ra.address,
      });

      expect(events.length).to.equal(1);
    }

    const assets = await contract.read.getDeployedWrappedAssets([0, 10]);

    expect(assets[0].length).to.equal(10);
    expect(assets[1].length).to.equal(10);

    const noAsset = await contract.read.getDeployedWrappedAssets([7, 10]);
    expect(noAsset[0].length).to.equal(0);
    expect(noAsset[1].length).to.equal(0);
  });

  it("should issue check is deployed wrapped assets", async function () {
    const { defaultSigner } = await helper.getSigners();

    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    for (let i = 0; i < 10; i++) {
      const { ra } = await helper.backedAssets();

      const asset = await contract.write.deployWrappedAsset([ra.address]);

      const events = await contract.getEvents.WrappedAssetDeployed({
        ra: ra.address,
      });

      expect(events.length).to.equal(1);
    }

    const assets = await contract.read.getDeployedWrappedAssets([0, 10]);

    expect(assets[0].length).to.equal(10);
    expect(assets[1].length).to.equal(10);

    for (const asset of assets[1]) {
      const isDeployed = await contract.read.isDeployed([asset]);
      expect(isDeployed).to.be.true;
    }
  });

  it("should deploy swap assets", async function () {
    const { defaultSigner } = await helper.getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    const { ra, pa } = await helper.backedAssets();

    const asset = await contract.write.deployWrappedAsset([ra.address]);

    const deployWaEvents = await contract.getEvents.WrappedAssetDeployed({
      ra: ra.address,
    });

    const wa = deployWaEvents[0].args.wa;

    await contract.write.deploySwapAssets([
      ra.address,
      pa.address,
      wa!,
      defaultSigner.account.address,
      BigInt(helper.expiry(100000)),
      parseEther("1"),
    ]);

    const events = await contract.getEvents.AssetDeployed({
      wa: wa!,
    });

    expect(events.length).to.equal(1);
  });

  it("should deploy swap sassets 100x", async function () {
    const { defaultSigner } = await helper.getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    const { ra, pa } = await helper.backedAssets();

    const asset = await contract.write.deployWrappedAsset([ra.address]);

    const deployWaEvents = await contract.getEvents.WrappedAssetDeployed({
      ra: ra.address,
    });

    const wa = deployWaEvents[0].args.wa;

    for (let i = 0; i < 100; i++) {
      await contract.write.deploySwapAssets([
        ra.address,
        pa.address,
        wa!,
        defaultSigner.account.address,
        BigInt(helper.expiry(100000)),
        parseEther("1"),
      ]);
    }

    const events = await contract.getEvents.AssetDeployed({
      wa: wa!,
    });

    expect(events.length).to.equal(1);
  });

  it("shoud get deployed swap assets paged", async function () {
    const { defaultSigner } = await helper.getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    const { ra, pa } = await helper.backedAssets();

    const asset = await contract.write.deployWrappedAsset([ra.address]);

    const deployWaEvents = await contract.getEvents.WrappedAssetDeployed({
      ra: ra.address,
    });

    const wa = deployWaEvents[0].args.wa;

    for (let i = 0; i < 20; i++) {
      await contract.write.deploySwapAssets([
        ra.address,
        pa.address,
        wa!,
        defaultSigner.account.address,
        BigInt(helper.expiry(100000)),
        parseEther("1"),
      ]);
    }

    const assets = await contract.read.getDeployedSwapAssets([wa!, 0, 10]);

    expect(assets[0].length).to.equal(10);
    expect(assets[1].length).to.equal(10);

    const noAsset = await contract.read.getDeployedSwapAssets([wa!, 7, 10]);

    for (const asset1 of noAsset[0]) {
      expect(asset1).to.be.equal("0x0000000000000000000000000000000000000000");
    }

    for (const asset of noAsset[1]) {
      expect(asset).to.be.equal("0x0000000000000000000000000000000000000000");
    }
  });

  it("should issue check is deployed swap assets", async function () {
    const { defaultSigner } = await helper.getSigners();
    const contract = await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });

    await contract.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });

    const { ra, pa } = await helper.backedAssets();

    const asset = await contract.write.deployWrappedAsset([ra.address]);

    const deployWaEvents = await contract.getEvents.WrappedAssetDeployed({
      ra: ra.address,
    });

    const wa = deployWaEvents[0].args.wa;

    for (let i = 0; i < 10; i++) {
      await contract.write.deploySwapAssets([
        ra.address,
        pa.address,
        wa!,
        defaultSigner.account.address,
        BigInt(helper.expiry(100000)),
        parseEther("1"),
      ]);
    }

    const assets = await contract.read.getDeployedSwapAssets([wa!, 0, 10]);

    expect(assets[0].length).to.equal(10);
    expect(assets[1].length).to.equal(10);

    for (const asset of assets[1]) {
      const isDeployed = await contract.read.isDeployed([asset]);
      expect(isDeployed).to.be.true;
    }
  });
});
