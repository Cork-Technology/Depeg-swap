import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

import {
  Address,
  formatEther,
  parseEther,
  WalletClient,
  zeroAddress,
} from "viem";
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
  let checksummedDefaultSigner: Address;

  let fixture: Awaited<
    ReturnType<typeof helper.ModuleCoreWithInitializedPsmLv>
  >;
  let pool: Awaited<ReturnType<typeof helper.issueNewSwapAssets>>;

  const getDs = async (address: Address) => {
    return await hre.viem.getContractAt("ERC20", address);
  };

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, signers } = helper.getSigners(__signers));
    secondSigner = signers[1];
  });

  async function localFixture() {
    return await helper.ModuleCoreWithInitializedPsmLv();
  }

  beforeEach(async () => {
    checksummedDefaultSigner = ethers.utils.getAddress(
      defaultSigner.account.address
    ) as Address;
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

  describe("onNewIssuance", function () {
    it("Revert onNewIssuance when called by non owner", async function () {
      await expect(
        fixture.dsFlashSwapRouter.contract.write.onNewIssuance([
          pool.Id,
          pool.dsId,
          zeroAddress,
          zeroAddress,
          depositAmount,
          zeroAddress,
          zeroAddress,
        ])
      ).to.be.rejectedWith(
        `OwnableUnauthorizedAccount("${checksummedDefaultSigner}")`
      );
    });
  });

  describe("emptyReserve", function () {
    it("Revert emptyReserve when called by non owner", async function () {
      await expect(
        fixture.dsFlashSwapRouter.contract.write.emptyReserve([
          pool.Id,
          pool.dsId,
        ])
      ).to.be.rejectedWith(
        `OwnableUnauthorizedAccount("${checksummedDefaultSigner}")`
      );
    });
  });

  describe("emptyReservePartial", function () {
    it("Revert emptyReservePartial when called by non owner", async function () {
      await expect(
        fixture.dsFlashSwapRouter.contract.write.emptyReservePartial([
          pool.Id,
          pool.dsId,
          10n
        ])
      ).to.be.rejectedWith(
        `OwnableUnauthorizedAccount("${checksummedDefaultSigner}")`
      );
    });
  });

  describe("addReserve", function () {
    it("Revert addReserve when called by non owner", async function () {
      await expect(
        fixture.dsFlashSwapRouter.contract.write.emptyReservePartial([
          pool.Id,
          pool.dsId,
          10n
        ])
      ).to.be.rejectedWith(
        `OwnableUnauthorizedAccount("${checksummedDefaultSigner}")`
      );
    });
  });

  describe("Sell DS", function () {
    const dsAmount = parseEther("5");
    let dsContract: Awaited<ReturnType<typeof getDs>>;

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

      dsContract = await getDs(pool.ds!);
    });

    it("should return correct preview of selling DS", async function () {
      const previewAmountOut =
        await fixture.dsFlashSwapRouter.contract.read.previewSwapDsforRa([
          pool.Id,
          pool.dsId!,
          dsAmount,
        ]);

      await dsContract.write.approve([
        fixture.dsFlashSwapRouter.contract.address,
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

    it("should sell DS : Permit", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiry));
      const permitmsg = await helper.permit({
        amount: dsAmount,
        deadline,
        erc20contractAddress: dsContract.address!,
        psmAddress: fixture.dsFlashSwapRouter.contract.address,
        signer: defaultSigner,
      });

      const beforeBalance = await fixture.ra.read.balanceOf([
        defaultSigner.account.address,
      ]);

      await fixture.dsFlashSwapRouter.contract.write.swapDsforRa([
        pool.Id,
        pool.dsId!,
        dsAmount,
        BigInt(0),
        permitmsg,
        deadline,
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

    it("should sell DS : Approval", async function () {
      await dsContract.write.approve([
        fixture.dsFlashSwapRouter.contract.address,
        dsAmount,
      ]);

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

    it("should buy DS : Permit", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiry));
      const raProvided = parseEther("0.1009");
      await fixture.ra.write.mint([defaultSigner.account.address, raProvided]);

      const permitmsg = await helper.permit({
        amount: raProvided,
        deadline,
        erc20contractAddress: fixture.ra.address!,
        psmAddress: fixture.dsFlashSwapRouter.contract.address,
        signer: defaultSigner,
      });

      await fixture.dsFlashSwapRouter.contract.write.swapRaforDs([
        pool.Id,
        pool.dsId!,
        raProvided,
        BigInt(0),
        permitmsg,
        deadline,
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

    it("should buy DS : Approval", async function () {
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

      const amountOutPreview =
        await fixture.dsFlashSwapRouter.contract.read.previewSwapRaforDs([
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
