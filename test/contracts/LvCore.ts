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
  let redeemAmount: bigint;
  let expiry: number;
  let deadline: bigint;

  let fixture: Awaited<
    ReturnType<typeof helper.ModuleCoreWithInitializedPsmLv>
  >;

  let moduleCore: Awaited<ReturnType<typeof getModuleCore>>;
  let corkConfig: Awaited<ReturnType<typeof getCorkConfig>>;
  let Id: Awaited<ReturnType<typeof moduleCore.read.getId>>;

  const getModuleCore = async (address: Address) => {
    return await hre.viem.getContractAt("ModuleCore", address);
  };

  const getCorkConfig = async (address: Address) => {
    return await hre.viem.getContractAt("CorkConfig", address);
  };

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, secondSigner, signers } = helper.getSigners(__signers));
  });

  beforeEach(async () => {
    fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);

    depositAmount = parseEther("10");
    redeemAmount = parseEther("1");
    expiry = helper.expiry(1000000);
    deadline = BigInt(helper.expiry(expiry));

    moduleCore = await getModuleCore(fixture.moduleCore.address);
    corkConfig = await getCorkConfig(fixture.config.contract.address);

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.mint([secondSigner.account.address, depositAmount]);

    await fixture.ra.write.approve([moduleCore.address, depositAmount]);
    await fixture.ra.write.approve([moduleCore.address, depositAmount], {
      account: secondSigner.account,
    });
    Id = await moduleCore.read.getId([fixture.pa.address, fixture.ra.address]);
  });

  async function issueNewSwapAssets(expiry: any, options = {}) {
    return await helper.issueNewSwapAssets({
      expiry: expiry,
      moduleCore: moduleCore.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
      factory: fixture.factory.contract.address,
      ...options,
    });
  }

  async function pauseAllPools() {
    await corkConfig.write.updatePoolsStatus([Id, true, true, true, true], {
      account: defaultSigner.account,
    });
  }

  describe("depositLv", function () {
    it("depositLv should work correctly", async function () {
      await issueNewSwapAssets(helper.expiry(1000000));

      const result = await moduleCore.write.depositLv([Id, depositAmount]);

      expect(result).to.be.ok;

      const afterAllowance = await fixture.ra.read.allowance([
        defaultSigner.account.address,
        moduleCore.address,
      ]);

      expect(afterAllowance).to.be.equal(BigInt(0));

      const depositEvent = await moduleCore.getEvents.LvDeposited({
        id: Id,
        depositor: defaultSigner.account.address,
      });

      expect(depositEvent.length).to.be.equal(1);
      expect(depositEvent[0].args.amount).to.be.equal(depositAmount);
    });

    it("Revert depositLv when deposits paused", async function () {
      await pauseAllPools();
      await expect(
        moduleCore.write.depositLv([Id, depositAmount])
      ).to.be.rejectedWith("LVDepositPaused()");
    });
  });

  it("revert when depositing 0", async function () {
    await issueNewSwapAssets(helper.expiry(1000000));

    await expect(moduleCore.write.depositLv([Id, 0n])).to.be.rejectedWith(
      "ZeroDeposit()"
    );
  });

  describe("previewLvDeposit", function () {
    it("previewLvDeposit should work correctly", async function () {
      await issueNewSwapAssets(helper.expiry(1000000));

      const result = await moduleCore.read.previewLvDeposit([
        Id,
        depositAmount,
      ]);
      expect(result).to.be.equal(depositAmount);
    });

    it("Revert previewLvDeposit when deposits paused", async function () {
      await pauseAllPools();
      await expect(
        moduleCore.read.previewLvDeposit([Id, depositAmount])
      ).to.be.rejectedWith("LVDepositPaused()");
    });
  });

  describe("redeemExpiredLv", function () {
    it("should redeem expired : Permit", async function () {
      const { Id, dsId } = await issueNewSwapAssets(expiry);
      // just to buffer
      deadline = BigInt(helper.expiry(expiry + 2e3));

      await moduleCore.write.depositLv([Id, depositAmount]);
      await moduleCore.write.depositLv([Id, depositAmount], {
        account: secondSigner.account,
      });

      const msgPermit = await helper.permit({
        amount: depositAmount,
        deadline,
        erc20contractAddress: fixture.lv.address!,
        psmAddress: moduleCore.address,
        signer: secondSigner,
      });

      await time.increaseTo(expiry + 1e3);

      const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
        moduleCore.address,
      ]);

      await moduleCore.write.redeemExpiredLv(
        [Id, secondSigner.account.address, depositAmount, msgPermit, deadline],
        {
          account: secondSigner.account,
        }
      );

      const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
        moduleCore.address,
      ]);

      const event = await moduleCore.getEvents.LvRedeemExpired({
        Id: Id,
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

    it("should redeem expired : Approval", async function () {
      const { Id, dsId } = await issueNewSwapAssets(expiry);

      await moduleCore.write.depositLv([Id, depositAmount]);
      await moduleCore.write.depositLv([Id, depositAmount], {
        account: secondSigner.account,
      });

      await fixture.lv.write.approve([moduleCore.address, depositAmount], {
        account: secondSigner.account,
      });

      await time.increaseTo(expiry + 1e3);

      const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
        moduleCore.address,
      ]);

      await moduleCore.write.redeemExpiredLv(
        [Id, secondSigner.account.address, depositAmount],
        {
          account: secondSigner.account,
        }
      );

      const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
        moduleCore.address,
      ]);

      const event = await moduleCore.getEvents.LvRedeemExpired({
        Id: Id,
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

    it("Revert redeemExpiredLv when withdrawals paused", async function () {
      await pauseAllPools();
      const msgPermit = await helper.permit({
        amount: depositAmount,
        deadline,
        erc20contractAddress: fixture.lv.address!,
        psmAddress: moduleCore.address,
        signer: secondSigner,
      });
      await expect(
        moduleCore.write.redeemExpiredLv(
          [
            Id,
            secondSigner.account.address,
            depositAmount,
            msgPermit,
            deadline,
          ],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith("LVWithdrawalPaused()");
      await expect(
        moduleCore.write.redeemExpiredLv([
          Id,
          secondSigner.account.address,
          depositAmount + BigInt(1),
        ])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
    });
  });

  describe("previewRedeemExpiredLv", function () {
    it("Revert previewRedeemExpiredLv when withdrawals paused", async function () {
      await pauseAllPools();
      await expect(
        moduleCore.read.previewRedeemExpiredLv([Id, depositAmount])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
    });
  });

  describe("requestRedemption", function () {
    it("requestRedemption should work correctly - permit ", async function () {
      const { Id, dsId } = await issueNewSwapAssets(expiry);

      await moduleCore.write.depositLv([Id, depositAmount]);
      await moduleCore.write.depositLv([Id, depositAmount], {
        account: secondSigner.account,
      });

      const msgPermit = await helper.permit({
        amount: depositAmount,
        deadline,
        erc20contractAddress: fixture.lv.address!,
        psmAddress: moduleCore.address,
        signer: secondSigner,
      });

      const lvLockedBefore = await moduleCore.read.lockedLvfor(
        [Id, secondSigner.account.address],
        {
          account: secondSigner.account,
        }
      );
      const lvBalanceBefore = await fixture.lv.read.balanceOf([
        secondSigner.account.address,
      ]);

      await moduleCore.write.requestRedemption(
        [Id, depositAmount, msgPermit, deadline],
        {
          account: secondSigner.account,
        }
      );

      const lvLockedAfter = await moduleCore.read.lockedLvfor(
        [Id, secondSigner.account.address],
        {
          account: secondSigner.account,
        }
      );
      const lvBalanceAfter = await fixture.lv.read.balanceOf([
        secondSigner.account.address,
      ]);
      expect(depositAmount).to.be.equal(lvLockedAfter - lvLockedBefore);
      expect(depositAmount).to.be.equal(lvBalanceBefore - lvBalanceAfter);
    });

    it("requestRedemption should work correctly - Approval ", async function () {
      const { Id, dsId } = await issueNewSwapAssets(expiry);

      await moduleCore.write.depositLv([Id, depositAmount]);
      await moduleCore.write.depositLv([Id, depositAmount], {
        account: secondSigner.account,
      });

      await fixture.lv.write.approve([moduleCore.address, depositAmount], {
        account: secondSigner.account,
      });

      const lvLockedBefore = await moduleCore.read.lockedLvfor(
        [Id, secondSigner.account.address],
        {
          account: secondSigner.account,
        }
      );
      const lvBalanceBefore = await fixture.lv.read.balanceOf([
        secondSigner.account.address,
      ]);

      await moduleCore.write.requestRedemption([Id, depositAmount], {
        account: secondSigner.account,
      });

      const lvLockedAfter = await moduleCore.read.lockedLvfor(
        [Id, secondSigner.account.address],
        {
          account: secondSigner.account,
        }
      );
      const lvBalanceAfter = await fixture.lv.read.balanceOf([
        secondSigner.account.address,
      ]);
      expect(depositAmount).to.be.equal(lvLockedAfter - lvLockedBefore);
      expect(depositAmount).to.be.equal(lvBalanceBefore - lvBalanceAfter);
    });

    it("Revert requestRedemption when withdrawals paused", async function () {
      await pauseAllPools();
      const msgPermit = await helper.permit({
        amount: depositAmount,
        deadline,
        erc20contractAddress: fixture.lv.address!,
        psmAddress: moduleCore.address,
        signer: secondSigner,
      });
      await expect(
        moduleCore.write.requestRedemption([
          Id,
          redeemAmount,
          msgPermit,
          deadline,
        ])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
      await expect(
        moduleCore.write.requestRedemption([Id, redeemAmount])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
    });
  });

  it("should still be able to redeem after new issuance", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);

    await moduleCore.write.depositLv([Id, depositAmount]);
    await moduleCore.write.depositLv([Id, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([moduleCore.address, depositAmount], {
      account: secondSigner.account,
    });

    await moduleCore.write.requestRedemption([Id, depositAmount], {
      account: secondSigner.account,
    });

    await time.increase(expiry + 1);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      moduleCore.address,
    ]);

    const _ = await helper.issueNewSwapAssets({
      expiry: helper.expiry(1 * 1e18),
      factory: fixture.factory.contract.address,
      moduleCore: moduleCore.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    // should revert if we specified higher amount than requested
    await expect(
      moduleCore.write.redeemExpiredLv(
        [Id, secondSigner.account.address, depositAmount + BigInt(1)],
        {
          account: secondSigner.account,
        }
      )
    ).to.be.rejected;

    await moduleCore.write.redeemExpiredLv(
      [Id, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      moduleCore.address,
    ]);

    expect(afterModuleCoreLvBalance).to.be.equal(
      initialModuleCoreLvBalance - depositAmount
    );

    const event = await moduleCore.getEvents.LvRedeemExpired({
      Id: Id,
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

    await moduleCore.write.depositLv([Id, depositAmount]);
    await moduleCore.write.depositLv([Id, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([moduleCore.address, depositAmount]);

    await moduleCore.write.requestRedemption([Id, depositAmount]);

    await time.increase(expiry + 1);

    const redeemAmount = depositAmount / BigInt(2);

    await moduleCore.write.transferRedemptionRights([
      Id,
      secondSigner.account.address,
      depositAmount,
    ]);

    await moduleCore.write.redeemExpiredLv(
      [Id, secondSigner.account.address, redeemAmount],
      {
        account: secondSigner.account,
      }
    );

    const event = await moduleCore.getEvents.LvRedeemExpired({
      Id: Id,
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

  describe("redeemEarlyLv", function () {
    it("should redeem early : Permit", async function () {
      const { Id } = await issueNewSwapAssets(expiry);
      await moduleCore.write.depositLv([Id, depositAmount]);
      const msgPermit = await helper.permit({
        amount: redeemAmount,
        deadline,
        erc20contractAddress: fixture.lv.address!,
        psmAddress: moduleCore.address,
        signer: defaultSigner,
      });

      await moduleCore.write.redeemEarlyLv(
        [Id, defaultSigner.account.address, redeemAmount, msgPermit, deadline],
        {
          account: defaultSigner.account,
        }
      );
      const event = await moduleCore.getEvents
        .LvRedeemEarly({
          Id: Id,
          receiver: defaultSigner.account.address,
          redeemer: defaultSigner.account.address,
        })
        .then((e) => e[0]);
      expect(event.args.feePrecentage).to.be.equal(parseEther("5"));

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
          helper.calculateMinimumLiquidity(parseEther("0.95"))
        ),
        // the amount will be slightly less because this is the first issuance,
        // caused by liquidity lock up by uni v2
        // will receive slightly less ETH by 0,0000000000000001
        100
      );
      // 10% fee
      expect(event.args.fee).to.be.closeTo(
        ethers.BigNumber.from(parseEther("0.05")),
        // the amount of fee deducted will also slightles less because this is the first issuance,
        // caused by liquidity lock up by uni v2
        // will receive slightly less ETH by 0,0000000000000001
        100
      );
    });

    it("should redeem early : Approval", async function () {
      const { Id } = await issueNewSwapAssets(expiry);

      await moduleCore.write.depositLv([Id, depositAmount]);
      await fixture.lv.write.approve([moduleCore.address, depositAmount]);
      await moduleCore.write.redeemEarlyLv([
        Id,
        defaultSigner.account.address,
        redeemAmount,
      ]);
      const event = await moduleCore.getEvents
        .LvRedeemEarly({
          Id: Id,
          receiver: defaultSigner.account.address,
          redeemer: defaultSigner.account.address,
        })
        .then((e) => e[0]);
      expect(event.args.feePrecentage).to.be.equal(parseEther("5"));

      expect(event.args.amount).to.be.closeTo(
        ethers.BigNumber.from(
          helper.calculateMinimumLiquidity(parseEther("0.95"))
        ),
        // the amount will be slightly less because this is the first issuance,
        // caused by liquidity lock up by uni v2
        // will receive slightly less ETH by 0,0000000000000001
        100
      );
      // 10% fee
      expect(event.args.fee).to.be.closeTo(
        ethers.BigNumber.from(parseEther("0.05")),
        // the amount of fee deducted will also slightles less because this is the first issuance,
        // caused by liquidity lock up by uni v2
        // will receive slightly less ETH by 0,0000000000000001
        100
      );
    });

    it("Revert redeemEarlyLv when withdrawals paused", async function () {
      await pauseAllPools();
      const msgPermit = await helper.permit({
        amount: depositAmount,
        deadline,
        erc20contractAddress: fixture.lv.address!,
        psmAddress: moduleCore.address,
        signer: secondSigner,
      });
      await expect(
        moduleCore.write.redeemEarlyLv([
          Id,
          defaultSigner.account.address,
          redeemAmount,
          msgPermit,
          deadline,
        ])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
      await expect(
        moduleCore.write.redeemEarlyLv([
          Id,
          defaultSigner.account.address,
          redeemAmount,
        ])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
    });
  });

  // @yusak found this bug, cannot withdraw early if there's only 1 WA left in the pool
  it("should redeem early(cannot withdraw early if there's only 1 RA left in the pool)", async function () {
    const { Id } = await issueNewSwapAssets(expiry);

    await moduleCore.write.depositLv([Id, depositAmount]);
    await fixture.lv.write.approve([moduleCore.address, depositAmount]);
    await moduleCore.write.redeemEarlyLv([
      Id,
      defaultSigner.account.address,
      redeemAmount,
    ]);

    const event = await moduleCore.getEvents
      .LvRedeemEarly({
        Id: Id,
        receiver: defaultSigner.account.address,
        redeemer: defaultSigner.account.address,
      })
      .then((e) => e[0]);
    expect(event.args.amount).to.be.closeTo(
      ethers.BigNumber.from(
        helper.calculateMinimumLiquidity(parseEther("0.95"))
      ),
      // the amount will be slightly less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
    // 10% fee
    expect(event.args.feePrecentage).to.be.equal(parseEther("5"));
    // 10% fee
    expect(event.args.fee).to.be.closeTo(
      ethers.BigNumber.from(parseEther("0.05")),
      // the amount of fee deducted will also slightles less because this is the first issuance,
      // caused by liquidity lock up by uni v2
      // will receive slightly less ETH by 0,0000000000000001
      100
    );
  });

  it("should return correct preview expired redeem", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);

    await moduleCore.write.depositLv([Id, depositAmount]);
    await moduleCore.write.depositLv([Id, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([moduleCore.address, depositAmount]);
    await moduleCore.write.requestRedemption([Id, parseEther("5")]);

    await fixture.lv.write.approve([moduleCore.address, depositAmount], {
      account: secondSigner.account,
    });
    await moduleCore.write.requestRedemption([Id, depositAmount], {
      account: secondSigner.account,
    });

    await time.increase(expiry + 1);

    await moduleCore.write.redeemExpiredLv(
      [Id, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const [signer1ra, signer2pa, signer1approvedAmount] =
      await moduleCore.read.previewRedeemExpiredLv([Id, depositAmount]);

    expect(signer1ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(depositAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(signer2pa).to.be.equal(BigInt(0));
    expect(signer1approvedAmount).to.be.equal(parseEther("5"));
  });

  describe("previewRedeemEarlyLv", function () {
    it("should return correct preview early redeem", async function () {
      const { Id } = await issueNewSwapAssets(expiry);

      await moduleCore.write.depositLv([Id, depositAmount]);
      const [rcv, fee, precentage] = await moduleCore.read.previewRedeemEarlyLv(
        [Id, redeemAmount]
      );

      expect(precentage).to.be.equal(parseEther("5"));
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

    it("Revert previewRedeemEarlyLv when withdrawals paused", async function () {
      await pauseAllPools();
      await expect(
        moduleCore.read.previewRedeemEarlyLv([Id, depositAmount])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
    });
  });

  it("should be able to redeem without a cap when there's no new DS issuance", async function () {
    const { Id, dsId } = await issueNewSwapAssets(expiry);

    await moduleCore.write.depositLv([Id, depositAmount]);
    await moduleCore.write.depositLv([Id, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([moduleCore.address, depositAmount], {
      account: secondSigner.account,
    });

    // we intentionally request less than the deposit amount to test if it's possible to redeem without a cap
    const lessThanDepositAmount = parseEther("5");
    await moduleCore.write.requestRedemption([Id, lessThanDepositAmount], {
      account: secondSigner.account,
    });

    expect(
      await fixture.lv.read.balanceOf([secondSigner.account.address])
    ).to.be.equal(lessThanDepositAmount);

    await time.increase(expiry + 1);

    const initialModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      moduleCore.address,
    ]);

    await moduleCore.write.redeemExpiredLv(
      [Id, secondSigner.account.address, depositAmount],
      {
        account: secondSigner.account,
      }
    );

    const afterModuleCoreLvBalance = await fixture.lv.read.balanceOf([
      moduleCore.address,
    ]);

    expect(afterModuleCoreLvBalance).to.be.equal(parseEther("0"));

    const event = await moduleCore.getEvents.LvRedeemExpired({
      Id: Id,
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

    await moduleCore.write.depositLv([Id, depositAmount]);
    await moduleCore.write.depositLv([Id, depositAmount], {
      account: secondSigner.account,
    });

    await fixture.lv.write.approve([moduleCore.address, depositAmount], {
      account: secondSigner.account,
    });

    await moduleCore.write.requestRedemption([Id, depositAmount], {
      account: secondSigner.account,
    });

    expect(
      await fixture.lv.read.balanceOf([secondSigner.account.address])
    ).to.be.equal(parseEther("0"));

    await time.increase(expiry + 1);

    await helper.issueNewSwapAssets({
      expiry: helper.expiry(1 * 1e18),
      factory: fixture.factory.contract.address,
      moduleCore: moduleCore.address,
      config: fixture.config.contract.address,
      pa: fixture.pa.address,
      ra: fixture.ra.address,
    });

    const raLocked = await moduleCore.read.lockedLvfor([
      Id,
      secondSigner.account.address,
    ]);

    expect(raLocked).to.be.equal(depositAmount);

    const [ra, pa] = await moduleCore.read.reservedUserWithdrawal([Id]);

    expect(ra).to.be.closeTo(
      ethers.BigNumber.from(helper.calculateMinimumLiquidity(depositAmount)),
      // 1k delta, as the default ratio is 0.9
      1000
    );
    expect(pa).to.be.equal(BigInt(0));
  });

  it("cannot issue expired", async function () {
    expiry = helper.expiry(1000000) - helper.nowTimestampInSeconds();

    const Id = await moduleCore.read.getId([
      fixture.pa.address,
      fixture.ra.address,
    ]);

    await expect(
      moduleCore.write.issueNewDs(
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

  describe("earlyRedemptionFee", function () {
    it("earlyRedemptionFee should work correctly", async function () {
      let fees = await moduleCore.read.earlyRedemptionFee([Id]);
      expect(fees).to.equal(parseEther("5"));
    });
  });

  describe("vaultLp", function () {
    it("vaultLp should work correctly", async function () {
      expect(await moduleCore.read.vaultLp([fixture.Id])).to.equal(0n);
    });
  });
});
