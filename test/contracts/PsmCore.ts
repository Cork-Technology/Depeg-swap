import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("PSM core", function () {
  describe("issue pair", function () {
    it("should issue new ds", async function () {
      const { defaultSigner } = await helper.getSigners();
      const psmFixture = await loadFixture(
        helper.ModuleCoreWithInitializedPsmLv
      );
      const expiry = helper.expiry(10);

      const contract = await hre.viem.getContractAt(
        "ModuleCore",
        psmFixture.moduleCore.contract.address
      );

      const Id = await contract.read.getId([
        psmFixture.pa.address,
        psmFixture.ra.address,
      ]);

      await contract.write.issueNewDs([Id, BigInt(expiry), parseEther("1")], {
        account: defaultSigner.account,
      });

      const events = await contract.getEvents.Issued({
        Id,
        expiry: BigInt(expiry),
      });

      expect(events.length).to.equal(1);
    });
  });

  describe("commons", function () {
    it("should deposit", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
      const mintAmount = parseEther("1000");
      const expTime = 10000;

      await fixture.ra.write.approve([
        fixture.moduleCore.contract.address,
        mintAmount,
      ]);

      await helper.mintRa(
        fixture.ra.address,
        defaultSigner.account.address,
        mintAmount
      );

      (await hre.viem.getContractAt("ERC20", fixture.pa.address)).write.approve(
        [fixture.moduleCore.contract.address, parseEther("10")]
      );

      const { dsId } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 10000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        wa: fixture.wa.address,
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.moduleCore.contract.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem DS", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
      const mintAmount = parseEther("1000");
      const expTime = 10000;

      await fixture.ra.write.approve([
        fixture.moduleCore.contract.address,
        mintAmount,
      ]);

      await helper.mintRa(
        fixture.ra.address,
        defaultSigner.account.address,
        mintAmount
      );

      // just to buffer
      const deadline = BigInt(helper.expiry(expTime));

      (await hre.viem.getContractAt("ERC20", fixture.pa.address)).write.approve(
        [fixture.moduleCore.contract.address, parseEther("10")]
      );

      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 1000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        wa: fixture.wa.address,
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

      const depositEvents =
        await fixture.moduleCore.contract.getEvents.PsmDeposited({
          Id: fixture.Id,
          dsId,
          depositor: defaultSigner.account.address,
        });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([
        fixture.moduleCore.contract.address,
        mintAmount,
      ]);

      const permitmsg = await helper.permit({
        amount: parseEther("10"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.contract.address,
        signer: defaultSigner,
      });

      const lockedBalance = await fixture.moduleCore.contract.read.valueLocked([
        fixture.Id,
      ]);

      console.log("locked balance", formatEther(lockedBalance));

      await fixture.moduleCore.contract.write.redeemRaWithDs(
        [fixture.Id, dsId!, parseEther("10"), permitmsg, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.moduleCore.contract.getEvents.DsRedeemed({
        dsId: dsId,
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem CT", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
      const mintAmount = parseEther("1000");
      const expTime = 100000;

      await fixture.ra.write.approve([
        fixture.moduleCore.contract.address,
        mintAmount,
      ]);

      await helper.mintRa(
        fixture.ra.address,
        defaultSigner.account.address,
        mintAmount
      );

      // just to buffer
      const deadline = BigInt(helper.expiry(expTime));

      (await hre.viem.getContractAt("ERC20", fixture.pa.address)).write.approve(
        [fixture.moduleCore.contract.address, parseEther("10")]
      );

      const { dsId, ds, ct, expiry } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 10000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        wa: fixture.wa.address,
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

      await time.increaseTo(expiry);

      const msgPermit = await helper.permit({
        amount: parseEther("10"),
        deadline,
        erc20contractAddress: ct!,
        psmAddress: fixture.moduleCore.contract.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.contract.write.redeemWithCT(
        [fixture.Id, dsId!, parseEther("10"), msgPermit, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.moduleCore.contract.getEvents.CtRedeemed({
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      console.log(formatEther(event[0].args.amount!));

      expect(event.length).to.equal(1);
    });
  });
});

// TODO : test preview output to be the same as actual function call
// TODO : test redeem ct + ds in 1 scenario, verify the amount is correct!
// TODO : add test suites for different exchange rate entirely
