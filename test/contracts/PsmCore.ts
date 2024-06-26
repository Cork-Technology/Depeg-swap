import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";
import exp from "constants";

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

  describe("with exchange rate", function () {
    it("should deposit with correct exchange rate", async function () {
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

        // rates: parseEther(),
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
    // test("should redeem DS with correct exchange rate", async function () {});
    // test("should get correct preview output", async function () {});
  });

  describe("cancel position", function () {
    it("should cancel position", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
      const mintAmount = parseEther("1");
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

      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 10000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,

        rates: parseEther("0.5"),
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, parseEther("1")],
        {
          account: defaultSigner.account,
        }
      );

      const dsContract = await hre.viem.getContractAt("ERC20", ds!);
      const dsBalance = await dsContract.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(dsBalance).to.equal(parseEther("2"));

      const ctContract = await hre.viem.getContractAt("ERC20", ct!);
      const ctBalance = await ctContract.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(ctBalance).to.equal(parseEther("2"));

      await dsContract.write.approve([
        fixture.moduleCore.contract.address,
        parseEther("2"),
      ]);

      await ctContract.write.approve([
        fixture.moduleCore.contract.address,
        parseEther("2"),
      ]);

      await fixture.moduleCore.contract.write.redeemRaWithCtDs(
        [fixture.Id, parseEther("2")],
        {
          account: defaultSigner.account,
        }
      );

      const events = await fixture.moduleCore.contract.getEvents.Cancelled({
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
        dsId,
      });

      const event = events[0];

      expect(event.args.exchangeRates).to.equal(parseEther("0.5"));
      expect(event.args.swapAmount).to.equal(parseEther("2"));
      expect(event.args.raAmount).to.equal(parseEther("1"));

      const raBalance = await fixture.ra.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(raBalance).to.equal(parseEther("1"));

      const afterDsBalance = await dsContract.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(afterDsBalance).to.equal(parseEther("0"));

      const afterCtBalance = await ctContract.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(afterCtBalance).to.equal(parseEther("0"));
    });

    it("should preview cancel position", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
      const mintAmount = parseEther("1");
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

      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 10000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,

        rates: parseEther("0.5"),
      });

      const [raAmount, rates] =
        await fixture.moduleCore.contract.read.previewRedeemRaWithCtDs([
          fixture.Id,
          parseEther("2"),
        ]);

      expect(raAmount).to.equal(parseEther("1"));
      expect(rates).to.equal(parseEther("0.5"));
    });
  });
});

// TODO : test redeem ct + ds in 1 scenario, verify the amount is correct!
