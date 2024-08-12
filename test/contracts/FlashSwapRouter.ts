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

  beforeEach("router", async () => {
    fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);

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

  // it("should return the correct DS price", async function () {
  //   const dsPrice =
  //     await fixture.dsFlashSwapRouter.contract.read.getCurrentDsPrice([
  //       pool.Id,
  //       pool.dsId!,
  //     ]);

  //   expect(dsPrice).to.be.equal(parseEther("0.1"));
  // });

  it("should sell DS", async function () {
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

    // sell ds
    const dsAmount = parseEther("5");

    const ds = await hre.viem.getContractAt("ERC20", pool.ds!);
    await ds.write.approve([
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

  it("should return correct preview of selling DS", async function () { });
  
  it("should buy DS", async function () { });
  
  it("", async function () {});
});
