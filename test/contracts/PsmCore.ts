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
      const expiry = helper.expiry(1e18 * 1000);

      const contract = await hre.viem.getContractAt(
        "ModuleCore",
        psmFixture.moduleCore.contract.address
      );

      const Id = await contract.read.getId([
        psmFixture.pa.address,
        psmFixture.ra.address,
      ]);

      await contract.write.issueNewDs(
        [Id, BigInt(expiry), parseEther("1"), parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

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
      const redeemAmount = parseEther("5");
      const depositAmount = parseEther("10");
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
        [fixture.moduleCore.contract.address, depositAmount]
      );

      const { dsId, ds, ct, expiry } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 10000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, depositAmount],
        {
          account: defaultSigner.account,
        }
      );

      await time.increaseTo(expiry);

      const msgPermit = await helper.permit({
        amount: redeemAmount,
        deadline,
        erc20contractAddress: ct!,
        psmAddress: fixture.moduleCore.contract.address,
        signer: defaultSigner,
      });

      const [_, raReceivedPreview] =
        await fixture.moduleCore.contract.read.previewRedeemWithCt([
          fixture.Id,
          dsId!,
          redeemAmount,
        ]);

      expect(raReceivedPreview).to.equal(redeemAmount);

      await fixture.moduleCore.contract.write.redeemWithCT(
        [fixture.Id, dsId!, redeemAmount, msgPermit, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.moduleCore.contract.getEvents.CtRedeemed({
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      expect(event[0].args.amount!).to.equal(redeemAmount);
      expect(event[0].args.raReceived!).to.equal(redeemAmount);
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

    it("should redeem DS with correct exchange rate", async function () {
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

      // 2 RA
      const rates = parseEther("2");

      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 1000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        rates: rates,
      });
      const depositAmount = parseEther("10");
      const expectedAMount = parseEther("5");

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, depositAmount],
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
        amount: expectedAMount,
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.contract.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.contract.write.redeemRaWithDs(
        [fixture.Id, dsId!, expectedAMount, permitmsg, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.moduleCore.contract.getEvents.DsRedeemed({
        dsId: dsId,
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      expect(event[0].args.dsExchangeRate).to.equal(rates);
      expect(event[0].args.received).to.equal(depositAmount);
    });

    it("should get correct preview output", async function () {
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

      // 2 RA
      const rates = parseEther("2");

      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 1000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        rates: rates,
      });
      const depositAmount = parseEther("10");
      const expectedAMount = parseEther("5");

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, depositAmount],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.moduleCore.contract.getEvents.PsmDeposited({
        depositor: defaultSigner.account.address,
      });

      const raReceived =
        await fixture.moduleCore.contract.read.previewRedeemRaWithDs([
          fixture.Id,
          dsId!,
          expectedAMount,
        ]);

      expect(raReceived).to.equal(depositAmount);
    });
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

      expect(event.args.dSexchangeRates).to.equal(parseEther("0.5"));
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

  describe("repurchase", function () {
    it("should repurchase", async function () {
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
        [fixture.moduleCore.contract.address, parseEther("100")]
      );

      // 2 RA for every DS
      const rates = parseEther("2");
      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 1000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        rates,
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, parseEther("100")],
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

      await fixture.moduleCore.contract.write.redeemRaWithDs(
        [fixture.Id, dsId!, parseEther("10"), permitmsg, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const [availablePa, availableDs] =
        await fixture.moduleCore.contract.read.availableForRepurchase([
          fixture.Id,
        ]);

      expect(availablePa).to.equal(parseEther("10"));
      expect(availableDs).to.equal(parseEther("10"));

      // remember fee rate is fixed at 10%
      const [_, received, feePrecentage, fee, exchangeRate] =
        await fixture.moduleCore.contract.read.previewRepurchase([
          fixture.Id,
          parseEther("2"),
        ]);

      expect(received).to.equal(parseEther("0.9"));
      expect(feePrecentage).to.equal(parseEther("10"));
      expect(fee).to.equal(parseEther("0.2"));
      expect(exchangeRate).to.equal(parseEther("2"));

      await fixture.moduleCore.contract.write.repurchase([
        fixture.Id,
        parseEther("2"),
      ]);

      const event = await fixture.moduleCore.contract.getEvents
        .Repurchased({
          buyer: defaultSigner.account.address,
          id: fixture.Id,
        })
        .then((e) => e[0]);

      expect(event.args.received).to.equal(received);
      expect(event.args.fee).to.equal(fee);
      expect(event.args.exchangeRates).to.equal(exchangeRate);
      expect(event.args.feePrecentage).to.equal(feePrecentage);
    });

    it("shouldn't be able to repurchase after expired", async function () {
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
        [fixture.moduleCore.contract.address, parseEther("100")]
      );

      // 2 RA for every DS
      const rates = parseEther("2");
      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 1000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        rates,
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, parseEther("100")],
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

      await fixture.moduleCore.contract.write.redeemRaWithDs(
        [fixture.Id, dsId!, parseEther("10"), permitmsg, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const [availablePa, availableDs] =
        await fixture.moduleCore.contract.read.availableForRepurchase([
          fixture.Id,
        ]);

      expect(availablePa).to.equal(parseEther("10"));
      expect(availableDs).to.equal(parseEther("10"));

      time.increaseTo(helper.expiry(expTime) + 1);

      await expect(
        fixture.moduleCore.contract.write.repurchase([
          fixture.Id,
          parseEther("2"),
        ])
      ).to.be.rejected;
    });

    it("should allocate PA for CT wthdrawal correctly after repurchase", async function () {
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
        [fixture.moduleCore.contract.address, parseEther("100")]
      );

      // 1 RA for every DS
      const rates = parseEther("1");
      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 1000,
        moduleCore: fixture.moduleCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        rates,
      });

      await fixture.moduleCore.contract.write.depositPsm(
        [fixture.Id, parseEther("100")],
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
        amount: parseEther("50"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.contract.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.contract.write.redeemRaWithDs(
        [fixture.Id, dsId!, parseEther("50"), permitmsg, deadline],
        {
          account: defaultSigner.account,
        }
      );

      await fixture.moduleCore.contract.write.repurchase([
        fixture.Id,
        parseEther("25"),
      ]);

      await time.increaseTo(helper.expiry(expTime) + 1);

      const [paReceivedPreview, raReceivedPreview] =
        await fixture.moduleCore.contract.read.previewRedeemWithCt([
          fixture.Id,
          dsId!,
          parseEther("1"),
        ]);

      expect(helper.toNumber(raReceivedPreview)).to.approximately(
        helper.toNumber(parseEther("0.5")),
        helper.toNumber(parseEther("0.1"))
      );
      expect(helper.toNumber(paReceivedPreview)).to.approximately(
        helper.toNumber(parseEther("0.25")),
        helper.toNumber(parseEther("0.2"))
      );

      const deadline2 = BigInt(helper.expiry(1e10));

      const permitmsg2 = await helper.permit({
        amount: parseEther("1"),
        deadline: deadline2,
        erc20contractAddress: ct!,
        psmAddress: fixture.moduleCore.contract.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.contract.write.redeemWithCT(
        [fixture.Id, dsId!, parseEther("1"), permitmsg2, deadline2],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.moduleCore.contract.getEvents
        .CtRedeemed({
          Id: fixture.Id,
          redeemer: defaultSigner.account.address,
        })
        .then((e) => e[0]);

      expect(event.args.amount!).to.equal(parseEther("1"));

      expect(helper.toNumber(event.args.raReceived!)).to.approximately(
        helper.toNumber(parseEther("0.5")),
        helper.toNumber(parseEther("0.1"))
      );

      expect(helper.toNumber(event.args.paReceived!)).to.approximately(
        helper.toNumber(parseEther("0.25")),
        helper.toNumber(parseEther("0.2"))
      );
    });
  });

  // @yusak found this, cannot issue new DS on the third time while depositing to LV
  // caused by not actually mint CT + DS at issun
  it("should be able to issue DS for the third time", async function () {
    const { defaultSigner } = await helper.getSigners();
    const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);
    const mintAmount = parseEther("1000000");

    await fixture.ra.write.mint([defaultSigner.account.address, mintAmount]);
    await fixture.ra.write.approve([
      fixture.moduleCore.contract.address,
      mintAmount,
    ]);

    const Id = await fixture.moduleCore.contract.read.getId([
      fixture.pa.address,
      fixture.ra.address,
    ]);
    const expiryInterval = 1000;
    let expiry = helper.expiry(expiryInterval);

    for (let i = 0; i < 10; i++) {
      await fixture.moduleCore.contract.write.issueNewDs(
        [Id, BigInt(expiry), parseEther("1"), parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

      const events = await fixture.moduleCore.contract.getEvents.Issued({
        Id,
        expiry: BigInt(expiry),
      });

      await fixture.moduleCore.contract.write.depositLv([Id, parseEther("5")]);

      await fixture.lv.write.approve([
        fixture.moduleCore.contract.address,
        parseEther("10"),
      ]);

      await fixture.moduleCore.contract.write.requestRedemption([
        Id,
        parseEther("1"),
      ]);

      expect(events.length).to.equal(1);

      await time.increaseTo(expiry);

      expiry = expiry + expiryInterval;
    }
  });
});

// TODO : test redeem ct + ds in 1 scenario, verify the amount is correct!
