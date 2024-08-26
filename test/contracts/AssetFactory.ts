import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import { ethers } from "ethers";
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
  let checksummedSecondSigner: Address;

  const deployFactory = async () => {
    return await hre.viem.deployContract("AssetFactory", [], {
      client: {
        wallet: defaultSigner,
      },
    });
  };

  async function getCheckSummedAdrress(address: Address) {
    return ethers.utils.getAddress(address) as Address;
  }

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, secondSigner, signers } = helper.getSigners(__signers));
  });

  beforeEach(async () => {
    checksummedSecondSigner = ethers.utils.getAddress(
      secondSigner.account.address
    ) as Address;
    assetFactory = await loadFixture(deployFactory);

    await assetFactory.write.initialize([defaultSigner.account.address], {
      account: defaultSigner.account,
    });
  });

  it("should deploy AssetFactory", async function () {
    expect(assetFactory).to.be.ok;
    expect(await assetFactory.read.MAX_LIMIT()).to.equal(10);
  });

  describe("initialize", function () {
    it("Revert initialize when Already initialized", async function () {
      await expect(
        assetFactory.write.initialize([defaultSigner.account.address], {
          account: defaultSigner.account,
        })
      ).to.be.rejectedWith(`InvalidInitialization`);
    });
  });

  describe("deployLv", function () {
    it("Revert deployLv when called by non owner", async function () {
      const { ra, pa } = await helper.backedAssets();
      await expect(
        assetFactory.write.deployLv(
          [ra.address, pa.address, defaultSigner.account.address],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith(
        `OwnableUnauthorizedAccount("${checksummedSecondSigner}")`
      );
    });
  });

  describe("getDeployedAssets", function () {
    it("getDeployedAssets should work correctly", async function () {
      let lv: Address[] = [];
      let ra: Address[] = [];
      let pa: Address[] = [];
      for (let i = 0; i < 10; i++) {
        const backedAssets = await helper.backedAssets();
        pa.push(backedAssets.pa.address);
        ra.push(backedAssets.ra.address);
        await assetFactory.write.deployLv([
          ra[i],
          pa[i],
          defaultSigner.account.address,
        ]);
        const event = await assetFactory.getEvents
          .LvAssetDeployed({
            ra: ra[i]!,
          })
          .then((e) => e[0]);
        lv.push(event.args.lv!);
      }
      let assets = await assetFactory.read.getDeployedAssets([0, 5]);
      expect(assets[0].length).to.equal(5);
      expect(assets[1].length).to.equal(5);
      for (let i = 0; i < 5; i++) {
        expect(assets[0][i]).to.equal(await getCheckSummedAdrress(ra[i]));
        expect(assets[1][i]).to.equal(lv[i]);
      }

      assets = await assetFactory.read.getDeployedAssets([1, 5]);
      expect(assets[0].length).to.equal(5);
      expect(assets[1].length).to.equal(5);
      for (let i = 0; i < 5; i++) {
        expect(assets[0][i]).to.equal(await getCheckSummedAdrress(ra[i + 5]));
        expect(assets[1][i]).to.equal(lv[i + 5]);
      }
    });

    it("should correctly return empty array when queried more than current assets", async function () {
      const assets = await assetFactory.read.getDeployedAssets([7, 10]);
      expect(assets[0].length).to.equal(0);
      expect(assets[1].length).to.equal(0);
    });

    it("Revert getDeployedAssets when passed limit is more than max allowed value", async function () {
      await expect(
        assetFactory.read.getDeployedAssets([1, 11])
      ).to.be.rejectedWith(`LimitTooLong(10, 11)`);
    });
  });

  describe("deploySwapAssets", function () {
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

    it("Revert deploySwapAssets when called by non owner", async function () {
      const { ra, pa } = await helper.backedAssets();
      await expect(
        assetFactory.write.deploySwapAssets(
          [
            ra.address,
            pa.address,
            defaultSigner.account.address,
            BigInt(helper.expiry(100000)),
            parseEther("1"),
          ],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith(
        `OwnableUnauthorizedAccount("${checksummedSecondSigner}")`
      );
    });

    it("Revert deploySwapAssets when passed Invalid RA/PA", async function () {
      const { ra, pa } = await helper.backedAssets();
      await expect(
        assetFactory.write.deploySwapAssets([
          ra.address,
          pa.address,
          defaultSigner.account.address,
          BigInt(helper.expiry(100000)),
          parseEther("1"),
        ])
      ).to.be.rejectedWith(
        `NotExist("${await getCheckSummedAdrress(
          ra.address
        )}", "${await getCheckSummedAdrress(pa.address)}")`
      );
    });
  });

  describe("getDeployedSwapAssets", function () {
    it("getDeployedSwapAssets should get deployed swap assets paged correctly", async function () {
      const { ra, pa } = await helper.backedAssets();

      // deploy lv to signal that a pair exist
      await assetFactory.write.deployLv([
        ra.address,
        pa.address,
        defaultSigner.account.address,
      ]);

      let ct: Address[] = [];
      let ds: Address[] = [];
      for (let i = 0; i < 20; i++) {
        await assetFactory.write.deploySwapAssets([
          ra.address,
          pa.address,
          defaultSigner.account.address,
          BigInt(helper.expiry(100000)),
          parseEther("1"),
        ]);
        const event = await assetFactory.getEvents
          .AssetDeployed({
            ra: ra.address!,
          })
          .then((e) => e[0]);
        ct.push(event.args.ct!);
        ds.push(event.args.ds!);
      }

      let assets = await assetFactory.read.getDeployedSwapAssets([
        ra.address,
        pa.address,
        0,
        10,
      ]);
      expect(assets[0].length).to.equal(10);
      expect(assets[1].length).to.equal(10);
      for (let i = 0; i < 10; i++) {
        expect(assets[0][i]).to.equal(ct[i]);
        expect(assets[1][i]).to.equal(ds[i]);
      }

      assets = await assetFactory.read.getDeployedSwapAssets([
        ra.address,
        pa.address,
        1,
        10,
      ]);
      expect(assets[0].length).to.equal(10);
      expect(assets[1].length).to.equal(10);
      for (let i = 0; i < 10; i++) {
        expect(assets[0][i]).to.equal(ct[i + 10]);
        expect(assets[1][i]).to.equal(ds[i + 10]);
      }
    });

    it("should correctly return empty array when queried more than current assets", async function () {
      const { ra, pa } = await helper.backedAssets();
      const assets = await assetFactory.read.getDeployedSwapAssets([
        ra.address,pa.address,
        7,
        10,
      ]);
      expect(assets[0].length).to.equal(0);
      expect(assets[1].length).to.equal(0);
    });

    it("Revert getDeployedSwapAssets when passed limit is more than max allowed value", async function () {
      const { ra, pa } = await helper.backedAssets();
      await expect(
        assetFactory.read.getDeployedSwapAssets([ra.address,pa.address, 1, 11])
      ).to.be.rejectedWith(`LimitTooLong(10, 11)`);
    });
  });

  describe("isDeployed", function () {
    it("isDeployed should correctly check if swap assets deployed", async function () {
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
        pa.address,
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
});
