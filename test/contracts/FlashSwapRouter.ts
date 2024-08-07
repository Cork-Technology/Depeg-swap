import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

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

    depositAmount = parseEther("100");
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

  it("should return the correct DS price", async function () {
    const dsPrice =
      await fixture.dsFlashSwapRouter.contract.read.getCurrentDsPrice([
        pool.Id,
        pool.dsId!,
      ]);

    expect(dsPrice).to.be.equal(parseEther("0.1"));
  });

  it("should return correct RA amount in", async function () {
    const dsAmount = parseEther("2.5");
    // as the default price of the ds is 0.1 RA
    const expectedRaAmount = parseEther("0.25");
    const ra = await fixture.dsFlashSwapRouter.contract.read.previewSwapDsforRa(
      [pool.Id, pool.dsId!, dsAmount]
    );

    expect(ra).to.be.equal(expectedRaAmount);
  });

  it("should return correct DS amount out", async function () {
    const raAmount = parseEther("1");

    // for first issuance
    //
    // initialDsPrice = dsExchangeRate - ctReserve  / raReserve
    // targetDs = raAmount / initialDsPrice
    //
    // calculating new dsPrce after selling reserve from LV, essentially increasing the ra reserve and decreasing the ct reserve on the AMM since we repay with RA and borrow CT
    // dsPrice = dsExchangeRate - (ctReserve - (targetDs - (targetDS x 50%))) / raReserve + ((targetDs x 50%) - (initialDsPrice x (targetDs x 50%)))
    //
    // for subsequent issuance
    //
    // initialDsPrice = dsExchangeRate - ctReserve  / raReserve
    // targetDs = raAmount / initialDsPrice
    //
    // calculating new dsPrce after selling reserve from LV, essentially increasing the ra reserve and decreasing the ct reserve on the AMM since we repay with RA and borrow CT
    //
    // dsPrice = dsExchangeRate - (ctReserve - targetDs - (targetDS x 80%)) / raReserve + targetDs - (initialDsPrice x (targetDs x 80%))
    const expectedDsAmountOut = parseEther("10");
    const ds = await fixture.dsFlashSwapRouter.contract.read.previewSwapRaforDs(
      [pool.Id, pool.dsId!, raAmount]
    );

    expect(ds).to.be.equal(expectedDsAmountOut);
  });

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

    const dsAmount = parseEther("2.5");

    const ds = await hre.viem.getContractAt("ERC20", pool.ds!);
    await ds.write.approve([
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

    expect(event.args.amountOut).to.be.equal(dsAmount);
  });
});
