import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
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
      moduleCore: fixture.moduleCore.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      wa: fixture.wa.address,
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

    const { Id } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      wa: fixture.wa.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.moduleCore.contract.write.requestRedemption([Id]);
    await fixture.moduleCore.contract.write.requestRedemption([Id], {
      account: secondSigner.account,
    });

    await time.increase(expiry + 1);

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const event = await fixture.moduleCore.contract.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.equal(depositAmount);
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should not be able to redeem when not requested", async function () {
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
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      wa: fixture.wa.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);

    await time.increase(expiry + 1);

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: defaultSigner.account,
      }
    );

    await expect(
      fixture.moduleCore.contract.write.redeemExpiredLv(
        [lv, defaultSigner.account.address, depositAmount],
        {
          account: defaultSigner.account,
        }
      )
    ).to.be.rejected;
  });

  it("should redeem after transferring right", async function () {
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

    const { Id } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      wa: fixture.wa.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.moduleCore.contract.write.requestRedemption([Id]);

    await time.increase(expiry + 1);

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await fixture.moduleCore.contract.write.transferRedemptionRights([
      lv,
      secondSigner.account.address,
    ]);

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const event = await fixture.moduleCore.contract.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.equal(depositAmount);
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
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      wa: fixture.wa.address,
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

    const { Id } = await helper.issueNewSwapAssets({
      expiry,
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      wa: fixture.wa.address,
    });

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.moduleCore.contract.write.requestRedemption([Id]);
    await fixture.moduleCore.contract.write.requestRedemption([Id], {
      account: secondSigner.account,
    });

    await time.increase(expiry + 1);

    await fixture.lv.write.approve(
      [fixture.moduleCore.contract.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const [ra, pa] =
      await fixture.moduleCore.contract.read.previewRedeemExpiredLv([
        lv,
        depositAmount,
      ]);

    expect(ra).to.be.equal(depositAmount);
    expect(pa).to.be.equal(BigInt(0));
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
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      wa: fixture.wa.address,
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
});
