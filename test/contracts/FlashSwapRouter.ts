import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";
import { ethers } from "ethers";

describe("FlashSwapRouter", function () {
  let {
    defaultSigner,
    secondSigner,
    signers,
  }: ReturnType<typeof helper.getSigners> = {} as any;

  let depositAmount: bigint;
  let expiry: number;

  let fixture: Awaited<
    ReturnType<typeof helper.ModuleCoreWithInitializedPsmLv>
  >;
  let pool: Awaited<ReturnType<typeof helper.issueNewSwapAssets>>;

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, signers } = helper.getSigners(__signers));
    secondSigner = signers[1];
  });

  async function localFixture() {
    return await helper.ModuleCoreWithInitializedPsmLv();
   }

  beforeEach(async () => {
    fixture = await loadFixture(localFixture);

    depositAmount = parseEther("1900");
    expiry = helper.expiry(1000000);

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.approve([fixture.moduleCore.address, depositAmount]);

    pool = await helper.issueNewSwapAssets({
      config: fixture.config.contract.address,
      moduleCore: fixture.moduleCore.address,
      ra: fixture.ra.address,
      expiry,
      factory: fixture.factory.contract.address,
      pa: fixture.pa.address,
    });

    await fixture.moduleCore.write.depositLv([pool.Id, depositAmount]);
  });

  describe("Sell DS", function () {
    const dsAmount = parseEther("5");

    beforeEach(async () => {
      const raDepositAmount = parseEther("10");

      //deposit psm
      await fixture.ra.write.mint([
        defaultSigner.account.address,
        raDepositAmount,
      ]);

      await fixture.ra.write.approve([
        fixture.moduleCore.address,
        raDepositAmount,
      ]);

      await fixture.moduleCore.write.depositPsm([pool.Id, raDepositAmount]);

      const ds = await hre.viem.getContractAt("ERC20", pool.ds!);
      await ds.write.approve([
        fixture.dsFlashSwapRouter.contract.address,
        dsAmount,
      ]);
    });

    it("should return correct preview of selling DS", async function () {
      const previewAmountOut =
        await fixture.dsFlashSwapRouter.contract.read.previewSwapDsforRa([
          pool.Id,
          pool.dsId!,
          dsAmount,
        ]);

      await fixture.dsFlashSwapRouter.contract.write.swapDsforRa([
        pool.Id,
        pool.dsId!,
        dsAmount,
        BigInt(0),
      ]);

      const event = await fixture.dsFlashSwapRouter.contract.getEvents
        .DsSwapped({
          dsId: pool.dsId!,
          reserveId: pool.Id,
          user: defaultSigner.account.address,
        })
        .then((e) => e[0]);

      expect(event.args.amountOut).to.be.equal(previewAmountOut);
    });

    it("should sell DS", async function () {
      const beforeBalance = await fixture.ra.read.balanceOf([
        defaultSigner.account.address,
      ]);

      await fixture.dsFlashSwapRouter.contract.write.swapDsforRa([
        pool.Id,
        pool.dsId!,
        dsAmount,
        BigInt(0),
      ]);

      const event = await fixture.dsFlashSwapRouter.contract.getEvents
        .DsSwapped({
          dsId: pool.dsId!,
          reserveId: pool.Id,
          user: defaultSigner.account.address,
        })
        .then((e) => e[0]);

      expect(event.args.amountOut).to.be.closeTo(
        helper.toEthersBigNumer("0.477"),
        helper.toEthersBigNumer("0.001")
      );

      const afterBalance = await fixture.ra.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(afterBalance).to.be.equal(beforeBalance + event.args.amountOut!);
    });
  });

  describe("Buy DS", function () {
    beforeEach(async () => {
      const raDepositAmount = parseEther("10");

      //deposit psm
      await fixture.ra.write.mint([
        defaultSigner.account.address,
        raDepositAmount,
      ]);

      await fixture.ra.write.approve([
        fixture.moduleCore.address,
        raDepositAmount,
      ]);

      await fixture.moduleCore.write.depositPsm([pool.Id, raDepositAmount]);
    });

    it("should buy DS", async function () {
      
      const raProvided = parseEther("0.1009");
      await fixture.ra.write.mint([defaultSigner.account.address, raProvided]);

      await fixture.ra.write.approve([
        fixture.dsFlashSwapRouter.contract.address,
        raProvided,
      ]);

      await fixture.dsFlashSwapRouter.contract.write.swapRaforDs([
        pool.Id,
        pool.dsId!,
        raProvided,
        BigInt(0),
      ]);

      const event = await fixture.dsFlashSwapRouter.contract.getEvents
        .RaSwapped({
          dsId: pool.dsId!,
          reserveId: pool.Id,
          user: defaultSigner.account.address,
        })
        .then((e) => e[0]);

      expect(event.args.amountOut).to.be.closeTo(
        helper.toEthersBigNumer("1.01"),
        helper.toEthersBigNumer("0.01")
      );
    });

    it("should give correct buy DS preview", async function () {
      const raProvided = parseEther("0.1009");
      await fixture.ra.write.mint([defaultSigner.account.address, raProvided]);

      await fixture.ra.write.approve([
        fixture.dsFlashSwapRouter.contract.address,
        raProvided,
      ]);

      const amountOutPreview =await
        fixture.dsFlashSwapRouter.contract.read.previewSwapRaforDs([
          pool.Id,
          pool.dsId!,
          raProvided,
        ]);

      expect(amountOutPreview).to.be.closeTo(
        helper.toEthersBigNumer("1.01"),
        helper.toEthersBigNumer("0.01")
      );

      await fixture.dsFlashSwapRouter.contract.write.swapRaforDs([
        pool.Id,
        pool.dsId!,
        raProvided,
        BigInt(0),
      ]);

      const event = await fixture.dsFlashSwapRouter.contract.getEvents
        .RaSwapped({
          dsId: pool.dsId!,
          reserveId: pool.Id,
          user: defaultSigner.account.address,
        })
        .then((e) => e[0]);

      expect(event.args.amountOut).to.be.equal(amountOutPreview);
    });
  });
});