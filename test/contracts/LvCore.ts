import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import hre from "hardhat";
import * as helper from "../helper/TestHelper";
import { ethers } from "ethers";

describe("LvCore", function () {
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

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, secondSigner, signers } = helper.getSigners(__signers));
  });

  beforeEach(async () => {
    fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);

    depositAmount = parseEther("10");
    expiry = helper.expiry(1000000);

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([
      fixture.moduleCore.address,
      depositAmount,
    ]);
    await fixture.ra.write.approve(
      [fixture.moduleCore.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );
  });

  async function issueNewSwapAssets(expiry: any, options = {}) {
    return await helper.issueNewSwapAssets({
      expiry: expiry,
      moduleCore: fixture.moduleCore.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      factory: fixture.factory.contract.address,
      ...options,
    });
  }

  it("should deposit", async function () {
    await issueNewSwapAssets(helper.expiry(1000000));

    const lv = fixture.Id;
    const result = await fixture.moduleCore.write.depositLv([
      lv,
      depositAmount,
    ]);

    expect(result).to.be.ok;

    const afterAllowance = await fixture.ra.read.allowance([
      defaultSigner.account.address,
      fixture.moduleCore.address,
    ]);

    expect(afterAllowance).to.be.equal(BigInt(0));

    const depositEvent =
      await fixture.moduleCore.getEvents.LvDeposited({
        id: lv,
        depositor: defaultSigner.account.address,
      });

    expect(depositEvent.length).to.be.equal(1);
    expect(depositEvent[0].args.amount).to.be.equal(depositAmount);
  });

  it("should redeem expired : Permit", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);
    // just to buffer
    const deadline = BigInt(helper.expiry(expiry + 2e3));

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    const msgPermit = await helper.permit({
      amount: depositAmount,
      deadline,
      erc20contractAddress: fixture.lv.address!,
      psmAddress: fixture.moduleCore.contract.address,
      signer: secondSigner,
    });

    await time.increaseTo(expiry + 1e3);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.contract.address,
    ]);

    await fixture.moduleCore.contract.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount, msgPermit, deadline],
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

  it("should redeem expired : Approval", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await time.increaseTo(expiry + 1e3);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.address,
    ]);

    await fixture.moduleCore.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.address,
    ]);

    const event = await fixture.moduleCore.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(depositAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should still be able to redeem after new issuance", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);
    const lv = fixture.Id;

    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await fixture.moduleCore.write.requestRedemption(
      [Id, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await time.increase(expiry + 1);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.address,
    ]);

    const _ = await helper.issueNewSwapAssets({
      expiry: helper.expiry(1 * 1e18),
      factory: fixture.factory.contract.address,
      moduleCore: fixture.moduleCore.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    // should revert if we specified higher amount than requested
    await expect(
      fixture.moduleCore.write.redeemExpiredLv(
        [lv, secondSigner.account.address, depositAmount + BigInt(1)],
        {
          account: secondSigner.account,
        }
      )
    ).to.be.rejected;

    await fixture.moduleCore.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.address,
    ]);

    expect(afterModuleCoreLvBalance).to.be.equal(
      initialModuleCoreLvBalance - depositAmount
    );

    const event = await fixture.moduleCore.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(depositAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should redeem after transferring right", async function () {
    expiry = helper.expiry(1000000000000);

    const { Id, dsId } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([
      fixture.moduleCore.address,
      depositAmount,
    ]);

    await fixture.moduleCore.write.requestRedemption([
      Id,
      depositAmount,
    ]);

    await time.increase(expiry + 1);

    const redeemAmount = depositAmount / BigInt(2);

    await fixture.moduleCore.write.transferRedemptionRights([
      lv,
      secondSigner.account.address,
      depositAmount,
    ]);

    await fixture.moduleCore.write.redeemExpiredLv(
      [lv, secondSigner.account.address, redeemAmount],
      {
        account: secondSigner.account,
      }
    );

    const event = await fixture.moduleCore.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(redeemAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should redeem early : Permit", async function () {
    const { Id } = await issueNewSwapAssets(expiry);
    // just to buffer
    const deadline = BigInt(helper.expiry(expiry));

    const lv = fixture.Id;
    await fixture.moduleCore.contract.write.depositLv([lv, depositAmount]);
    const msgPermit = await helper.permit({
      amount: depositAmount,
      deadline,
      erc20contractAddress: fixture.lv.address!,
      psmAddress: fixture.moduleCore.contract.address,
      signer: defaultSigner,
    });
    await fixture.moduleCore.contract.write.redeemEarlyLv(
      [lv, defaultSigner.account.address, parseEther("1"), msgPermit, deadline],
      {
        account: defaultSigner.account,
      }
    );
    const event = await fixture.moduleCore.contract.getEvents
      .LvRedeemEarly({
        Id: lv,
        receiver: defaultSigner.account.address,
        redeemer: defaultSigner.account.address,
      })
      .then((e) => e[0]);
    expect(event.args.feePrecentage).to.be.equal(parseEther("10"));

    console.log(
      "event.args.amount                                          :",
      formatEther(event.args.amount!)
    );
    console.log(
      "helper.calculateMinimumLiquidity(parseEther('0.9'))        :",
      "0.9"
    );

    expect(event.args.amount).to.be.closeTo(
      ethers.BigNumber.from(
        helper.calculateMinimumLiquidity(parseEther("0.9"))
      ),
      // the amount will be slightly less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
    // 10% fee
    expect(event.args.fee).to.be.closeTo(
      ethers.BigNumber.from(parseEther("0.1")),
      // the amount of fee deducted will also slightles less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
  });

  it("should redeem early : Approval", async function () {
    const { Id } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.lv.write.approve([
      fixture.moduleCore.address,
      depositAmount,
    ]);
    await fixture.moduleCore.write.redeemEarlyLv([
      lv,
      defaultSigner.account.address,
      parseEther("1"),
    ]);
    const event = await fixture.moduleCore.getEvents
      .LvRedeemEarly({
        Id: lv,
        receiver: defaultSigner.account.address,
        redeemer: defaultSigner.account.address,
      })
      .then((e) => e[0]);
    expect(event.args.feePrecentage).to.be.equal(parseEther("10"));

    expect(event.args.amount).to.be.closeTo(
      ethers.BigNumber.from(
        helper.calculateMinimumLiquidity(parseEther("0.9"))
      ),
      // the amount will be slightly less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
    // 10% fee
    expect(event.args.fee).to.be.closeTo(
      ethers.BigNumber.from(parseEther("0.1")),
      // the amount of fee deducted will also slightles less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
  });

  // @yusak found this bug, cannot withdraw early if there's only 1 WA left in the pool
  it("should redeem early(cannot withdraw early if there's only 1 RA left in the pool)", async function () {
    const { Id } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.lv.write.approve([
      fixture.moduleCore.address,
      depositAmount,
    ]);
    await fixture.moduleCore.write.redeemEarlyLv([
      lv,
      defaultSigner.account.address,
      parseEther("1"),
    ]);

    const event = await fixture.moduleCore.getEvents
      .LvRedeemEarly({
        Id: lv,
        receiver: defaultSigner.account.address,
        redeemer: defaultSigner.account.address,
      })
      .then((e) => e[0]);
    expect(event.args.amount).to.be.closeTo(
      ethers.BigNumber.from(
        helper.calculateMinimumLiquidity(parseEther("0.9"))
      ),
      // the amount will be slightly less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
    // 10% fee
    expect(event.args.feePrecentage).to.be.equal(parseEther("10"));
    // 10% fee
    expect(event.args.fee).to.be.closeTo(
      ethers.BigNumber.from(parseEther("0.1")),
      // the amount of fee deducted will also slightles less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
  });

  it("should return correct preview expired redeem", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([
      fixture.moduleCore.address,
      depositAmount,
    ]);
    await fixture.moduleCore.write.requestRedemption([
      Id,
      parseEther("5"),
    ]);

    await fixture.lv.write.approve(
      [fixture.moduleCore.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );
    await fixture.moduleCore.write.requestRedemption(
      [Id, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await time.increase(expiry + 1);

    await fixture.moduleCore.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const [signer1ra, signer2pa, signer1approvedAmount] =
      await fixture.moduleCore.read.previewRedeemExpiredLv([
        lv,
        depositAmount,
      ]);

    expect(signer1ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(depositAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(signer2pa).to.be.equal(BigInt(0));
    expect(signer1approvedAmount).to.be.equal(parseEther("5"));
  });

  it("should return correct preview early redeem", async function () {
    const { Id } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    const [rcv, fee, precentage] =
      await fixture.moduleCore.read.previewRedeemEarlyLv([
        lv,
        parseEther("1"),
      ]);

    expect(precentage).to.be.equal(parseEther("10"));
    expect(fee).to.be.closeTo(
      ethers.BigNumber.from(parseEther("0.1")),
      // the amount of fee deducted will also slightles less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001

      // 0.06 to take into account 0.9 initial ratio of the pool, which means we receive more RA compared to if the ratio is 1
      ethers.utils.parseEther("0.06")
    );

    expect(rcv).to.be.closeTo(
      ethers.BigNumber.from(
        helper.calculateMinimumLiquidity(parseEther("0.9"))
      ),
      // the amount will be slightly less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001

      // 0.06 to take into account 0.9 initial ratio of the pool, which means we receive more RA compared to if the ratio is 1
      ethers.utils.parseEther("0.06")
    );
  });

  it("should be able to redeem without a cap when there's no new DS issuance", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    // we intentionally request less than the deposit amount to test if it's possible to redeem without a cap
    const lessThanDepositAmount = parseEther("5");
    await fixture.moduleCore.write.requestRedemption(
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
      fixture.moduleCore.address,
    ]);

    await fixture.moduleCore.write.redeemExpiredLv(
      [lv, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      fixture.moduleCore.address,
    ]);

    expect(afterModuleCoreLvBalance).to.be.equal(parseEther("0"));

    const event = await fixture.moduleCore.getEvents.LvRedeemExpired({
      Id: lv,
      receiver: secondSigner.account.address,
    });

    expect(event.length).to.be.equal(1);

    expect(event[0].args.ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(depositAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(event[0].args.pa).to.be.equal(BigInt(0));
  });

  it("should separate liquidity correctly at new issuance", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);

    const lv = fixture.Id;
    await fixture.moduleCore.write.depositLv([lv, depositAmount]);
    await fixture.moduleCore.write.depositLv([lv, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve(
      [fixture.moduleCore.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    await fixture.moduleCore.write.requestRedemption(
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
      moduleCore: fixture.moduleCore.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const raLocked = await fixture.moduleCore.read.lockedLvfor([
      Id,
      secondSigner.account.address,
    ]);

    expect(raLocked).to.be.equal(depositAmount);

    const [ra, pa] =
      await fixture.moduleCore.read.reservedUserWithdrawal([Id]);

    expect(ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(depositAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(pa).to.be.equal(BigInt(0));
  });

  it("cannot issue expired", async function () {
    expiry = helper.expiry(1000000) - helper.nowTimestampInSeconds();

    const Id = await fixture.moduleCore.read.getId([
      fixture.pa.address,
      fixture.ra.address,
    ]);

    await expect(
      fixture.moduleCore.write.issueNewDs(
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
