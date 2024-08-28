import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import { ethers } from "ethers";
import hre from "hardhat";
import { Address, parseEther } from "viem";

import * as helper from "../helper/TestHelper";

describe("Asset", function () {
  let {
    defaultSigner,
    secondSigner,
    signers,
  }: ReturnType<typeof helper.getSigners> = {} as any;

  let asset: Awaited<ReturnType<typeof deployAsset>>;

  async function getCheckSummedAdrress(address: Address) {
    return ethers.utils.getAddress(address) as Address;
  }

  const deployExchangeRate = async () => {
    return await hre.viem.deployContract("ExchangeRate", [1000n]);
  };

  const deployExpiry = async () => {
    return await hre.viem.deployContract("Expiry", [
      BigInt(helper.expiry(100)),
    ]);
  };

  const deployAsset = async () => {
    return await hre.viem.deployContract("Asset", [
      "Demo-Prefix",
      "Demo-Pair",
      defaultSigner.account.address,
      BigInt(helper.expiry(100) + 1000),
      100n,
    ]);
  };

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, secondSigner, signers } = helper.getSigners(__signers));
  });

  beforeEach(async () => {
    asset = await loadFixture(deployAsset);
  });

  describe("ExchangeRate", function () {
    it("should deploy ExchangeRate correctly", async function () {
      let exchangeRate = await loadFixture(deployExchangeRate);
      expect(exchangeRate).to.be.ok;
      expect(await exchangeRate.read.exchangeRate()).to.equal(1000n);
    });
  });

  describe("Expiry", function () {
    it("should deploy Expiry correctly", async function () {
      let expiry = await loadFixture(deployExpiry);
      expect(expiry).to.be.ok;
      expect(await expiry.read.isExpired()).to.equal(false);
    });

    it("Expiry deployement should revert when passed invalid value", async function () {
      await expect(hre.viem.deployContract("Expiry", [1n])).to.be.rejectedWith(
        `Expired`
      );
      expect(hre.viem.deployContract("Expiry", [0n])).to.be.ok;
    });

    it("isExpired should work correctly", async function () {
      let expiry = await loadFixture(deployExpiry);
      expect(await expiry.read.isExpired()).to.equal(false);
      await time.increaseTo(helper.expiry(200) + 2000);
      expect(await expiry.read.isExpired()).to.equal(true);

      let expireContract = await hre.viem.deployContract("Expiry", [0n]);
      expect(await expireContract.read.isExpired()).to.equal(false);
      await time.increaseTo(helper.expiry(2000) + 2000);
      expect(await expireContract.read.isExpired()).to.equal(false);
    });

    it("expiry should return correct value", async function () {
      let expiry = await loadFixture(deployExpiry);
      expect(await expiry.read.expiry()).to.equal(
        BigInt(await helper.expiry(100))
      );
      await time.increaseTo(helper.expiry(200) + 1);
      expect(await expiry.read.expiry()).to.equal(
        BigInt(await helper.expiry(100))
      );

      let expireContract = await hre.viem.deployContract("Expiry", [0n]);
      expect(await expireContract.read.expiry()).to.equal(0n);
      await time.increaseTo(helper.expiry(400) + 1);
      expect(await expireContract.read.expiry()).to.equal(0n);
    });
  });

  describe("Asset", function () {
    it("should deploy Asset correctly", async function () {
      expect(asset).to.be.ok;
      expect(await asset.read.owner()).to.equal(
        await getCheckSummedAdrress(defaultSigner.account.address)
      );
      // 
      expect(await asset.read.expiry()).to.closeTo(
        helper.toEthersBigNumer(BigInt(helper.expiry(100) + 1000)),
        // workaround for hardhat test, it never has exact value
        helper.toEthersBigNumer(1n)
      );
      expect(await asset.read.isExpired()).to.equal(false);
      expect(await asset.read.exchangeRate()).to.equal(100n);
      expect(await asset.read.name()).to.equal("Demo-Prefix-Demo-Pair");
      expect(await asset.read.symbol()).to.equal("Demo-Prefix-Demo-Pair");
    });

    it("mint should work correctly", async function () {
      expect(
        await asset.read.balanceOf([secondSigner.account.address])
      ).to.equal(0n);
      await asset.write.mint([secondSigner.account.address, parseEther("10")]);
      expect(
        await asset.read.balanceOf([secondSigner.account.address])
      ).to.equal(parseEther("10"));
    });

    it("mint should revert when called by non-owner", async function () {
      await expect(
        asset.write.mint([secondSigner.account.address, parseEther("10")], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith(
        `OwnableUnauthorizedAccount("${await getCheckSummedAdrress(
          secondSigner.account.address
        )}")`
      );
    });
  });
});
