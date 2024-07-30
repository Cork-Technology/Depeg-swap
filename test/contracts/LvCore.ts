import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("LvCore", function () {
  it("should deposit", async function () {
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner } = await helper.getSigners();

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await helper.issueNewSwapAssets({
      expiry: helper.expiry(1000000),
      factory: fixture.factory.contract.address,
      config: fixture.config.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    const result = await fixture.moduleCore.contract.write.depositLv([
      lv,
      depositAmount,
    ]);

    expect(result).to.be.ok;

    const afterAllowance = await fixture.ra.read.allowance([
      defaultSigner.account.address,
      fixture.moduleCore.contract.address,
    ]);

    expect(afterAllowance).to.be.equal(BigInt(0));

    const depositEvent =
      await fixture.moduleCore.contract.getEvents.LvDeposited({
        id: lv,
        depositor: defaultSigner.account.address,
      });

    expect(depositEvent.length).to.be.equal(1);
    expect(depositEvent[0].args.amount).to.be.equal(depositAmount);
  });

  it("should redeem expired", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();
    const secondSigner = signers[1];

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await fixture.ra.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const { Id, dsId } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await time.increaseTo(expiry + 1e3);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.contract.address,
    ]);

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.contract.address,
    ]);

    const event = await fixture.moduleCore.contract.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.equal(
      helper.calculateMinimumLiquidity(depositAmount)
    );
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should still be able to redeem after new issuance", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();
    const secondSigner = signers[1];

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await fixture.ra.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const { Id, dsId } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;

    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await fixture.moduleCore.contract.write.requestRedemption(
      [Id, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await time.increase(expiry + 1);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.contract.address,
    ]);

    const _ = await helper.issueNewSwapAssets({
      expiry: helper.expiry(1 * 1e18),
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    // should revert if we specified higher amount than requested
    await expect(
      fixture.moduleCore.contract.write.redeemExpiredLv(
        [lv, secondSigner.account.address, depositAmount + BigInt(1)],
        {
          account: secondSigner.account,
        }
      )
    ).to.be.rejected;

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.contract.address,
    ]);

    expect(afterModuleCoreLvBalance).to.be.equal(
      initialModuleCoreLvBalance - depositAmount
    );

    const event = await fixture.moduleCore.contract.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.equal(
      helper.calculateMinimumLiquidity(depositAmount)
    );
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should redeem after transferring right", async function () {
    const expiry = helper.expiry(1000000000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();
    const secondSigner = signers[1];

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await fixture.ra.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const { Id, dsId } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await fixture.moduleCore.contract.write.requestRedemption([
      Id,
      depositAmount,
    ]);

    await time.increase(expiry + 1);

    const redeemAmount = depositAmount / BigInt(2);

    await fixture.moduleCore.contract.write.transferRedemptionRights([
      lv,
      secondSigner.account.address,
      depositAmount,
    ]);

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, redeemAmount],
      {
        account: secondSigner.account,
      }
    );

    const event = await fixture.moduleCore.contract.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.equal(helper.calculateMinimumLiquidity(redeemAmount));
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should redeem early", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    const { Id } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.lv.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);
    await fixture.moduleCore.contract.write.redeemEarlyLv([
      lv,
      defaultSigner.account.address,
      parseEther("1"),
    ]);
    const event = await fixture.moduleCore.contract.getEvents
      .LvRedeemEarly({
        Id: lv,
        receiver: defaultSigner.account.address,
        redeemer: defaultSigner.account.address,
      })
      .then((e) => e[0]);
    expect(event.args.feePrecentage).to.be.equal(parseEther("10"));
    expect(event.args.amount).to.be.equal(parseEther("0.9"));
    // 10% fee
    expect(event.args.fee).to.be.equal(parseEther("0.1"));
  });

  // @yusak found this bug, cannot withdraw early if there's only 1 WA left in the pool
  it("should redeem early", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("1");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    const { Id } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.lv.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);
    await fixture.moduleCore.contract.write.redeemEarlyLv([
      lv,
      defaultSigner.account.address,
      parseEther("1"),
    ]);

    const event = await fixture.moduleCore.contract.getEvents
      .LvRedeemEarly({
        Id: lv,
        receiver: defaultSigner.account.address,
        redeemer: defaultSigner.account.address,
      })
      .then((e) => e[0]);

    expect(event.args.fee).to.be.equal(parseEther("0.1"));
    // 10% fee
    expect(event.args.feePrecentage).to.be.equal(parseEther("10"));
    expect(event.args.amount).to.be.equal(parseEther("0.9"));
  });

  it("should return correct preview expired redeem", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();
    const secondSigner = signers[1];

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await fixture.ra.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const { Id, dsId } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);
    await fixture.moduleCore.contract.write.requestRedemption([
      Id,
      parseEther("5"),
    ]);

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );
    await fixture.moduleCore.contract.write.requestRedemption(
      [Id, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await time.increase(expiry + 1);

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const [signer1ra, signer2pa, signer1approvedAmount] =
      await fixture.moduleCore.contract.read.previewRedeemExpiredLv([
        lv,
        depositAmount,
      ]);

    expect(signer1ra).to.be.equal(helper.calculateMinimumLiquidity(depositAmount));
    expect(signer2pa).to.be.equal(BigInt(0));
    expect(signer1approvedAmount).to.be.equal(parseEther("5"));
  });

  it("should return correct preview early redeem", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    const { Id } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.lv.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);
    const [rcv, fee, precentage] =
      await fixture.moduleCore.contract.read.previewRedeemEarlyLv([
        lv,
        parseEther("1"),
      ]);

    expect(fee).to.be.equal(parseEther("0.1"));
    // 10% fee
    expect(precentage).to.be.equal(parseEther("10"));
    expect(rcv).to.be.equal(parseEther("0.9"));
  });

  it("should be able to redeem without a cap when there's no new DS issuance", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();
    const secondSigner = signers[1];

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await fixture.ra.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const { Id, dsId } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    // we intentionally request less than the deposit amount to test if it's possible to redeem without a cap
    const lessThanDepositAmount = parseEther("5");
    await fixture.moduleCore.contract.write.requestRedemption(
      [Id, lessThanDepositAmount],
      {
        account: secondSigner.account,
      }
    );

    expect(
      await fixture.lv.read.balanceOf([secondSigner.account.address])
    ).to.be.equal(lessThanDepositAmount);

    await time.increase(expiry + 1);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.contract.address,
    ]);

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.contract.address,
    ]);

    expect(afterModuleCoreLvBalance).to.be.equal(parseEther("0"));

    const event = await fixture.moduleCore.contract.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.equal(depositAmount);
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should separate liquidity correctly at new issuance", async function () {
    const expiry = helper.expiry(1000000);
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();
    const secondSigner = signers[1];

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      depositAmount,
    ]);

    await fixture.ra.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const { Id, dsId } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await fixture.moduleCore.contract.write.requestRedemption(
      [Id, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    expect(
      await fixture.lv.read.balanceOf([secondSigner.account.address])
    ).to.be.equal(parseEther("0"));

    await time.increase(expiry + 1);

    await helper.issueNewSwapAssets({
      expiry: helper.expiry(1 * 1e18),
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const raLocked = await fixture.moduleCore.contract.read.lockedLvfor([
      Id,
      secondSigner.account.address,
    ]);

    expect(raLocked).to.be.equal(depositAmount);

    const [ra, pa] =
      await fixture.moduleCore.contract.read.reservedUserWithdrawal([Id]);

    expect(ra).to.be.equal(helper.calculateMinimumLiquidity(depositAmount));
    expect(pa).to.be.equal(BigInt(0));
  });

  it("cannot issue expired", async function () {
    const expiry = helper.expiry(1000000) - helper.nowTimestampInSeconds();
    const depositAmount = parseEther("10");
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const { defaultSigner, signers } = await helper.getSigners();

    const Id = await fixture.moduleCore.contract.read.getId([
      fixture.pa.address,
      fixture.ra.address,
    ]);

    await expect(
      fixture.moduleCore.contract.write.issueNewDs(
        [Id, BigInt(expiry), parseEther("1"), parseEther("1")],
        {
          account: defaultSigner.account,
        }
      )
    ).to.be.rejected;
  });

  describe("repurchase", function () {
    it("should accrue RA to LV holders after issuance", async function () {});
  });
});
