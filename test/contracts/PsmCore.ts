import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import {
  Address,
  formatEther,
  GetContractReturnType,
  parseEther,
  WalletClient,
} from "viem";
import * as helper from "../helper/TestHelper";
import { ArtifactsMap } from "hardhat/types/artifacts";
import { ethers } from "ethers";

describe("PSM core", function () {
  let {
    defaultSigner,
    secondSigner,
    signers,
  }: ReturnType<typeof helper.getSigners> = {} as any;

  let mintAmount: bigint;
  let expiryTime: number;

  let fixture: Awaited<
    ReturnType<typeof helper.ModuleCoreWithInitializedPsmLv>
  >;

  let moduleCore: Awaited<ReturnType<typeof getModuleCore>>;
  let corkConfig: Awaited<ReturnType<typeof getCorkConfig>>;
  let pa: Awaited<ReturnType<typeof getPA>>;

  const getModuleCore = async (address: Address) => {
    return await hre.viem.getContractAt("ModuleCore", address);
  };

  const getCorkConfig = async (address: Address) => {
    return await hre.viem.getContractAt("CorkConfig", address);
  };

  const getPA = async (address: Address) => {
    return await hre.viem.getContractAt("ERC20", address);
  };

  async function getCheckSummedAdrress(address: Address) {
    return ethers.utils.getAddress(address) as Address;
  }

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, secondSigner, signers } = helper.getSigners(__signers));
  });

  beforeEach(async () => {
    fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);

    moduleCore = await getModuleCore(fixture.moduleCore.address);
    corkConfig = await getCorkConfig(fixture.config.contract.address);

    expiryTime = 10000;
    mintAmount = parseEther("1000");

    await fixture.ra.write.approve([fixture.moduleCore.address, mintAmount]);

    await helper.mintRa(
      fixture.ra.address,
      defaultSigner.account.address,
      mintAmount
    );

    pa = await getPA(fixture.pa.address);
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

  describe("repurchaseFee", function () {
    it("repurchaseFee should work correctly", async function () {
      expect(await moduleCore.read.repurchaseFee([fixture.Id])).to.be.equals(
        0n
      );
      await corkConfig.write.updateRepurchaseFeeRate([fixture.Id, 10011n], {
        account: defaultSigner.account,
      });
      expect(await moduleCore.read.repurchaseFee([fixture.Id])).to.be.equals(
        10011n
      );
    });
  });

  describe("factory", function () {
    it("factory should work correctly", async function () {
      expect(await moduleCore.read.factory()).to.be.equals(
        await getCheckSummedAdrress(fixture.factory.contract.address)
      );
    });
  });

  describe("issue pair", function () {
    it("should issue new ds", async function () {
      expiryTime = helper.expiry(1e18 * 1000);

      const Id = await moduleCore.read.getId([
        fixture.pa.address,
        fixture.ra.address,
      ]);

      await corkConfig.write.issueNewDs([
        Id,
        BigInt(expiryTime),
        parseEther("1"),
        parseEther("5"),
      ]);

      const events = await moduleCore.getEvents.Issued({
        Id,
        expiry: BigInt(expiryTime),
      });

      expect(events.length).to.equal(1);
    });
  });

  describe("commons", function () {
    it("should deposit", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("10")]);

      const event = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should revert when depositing 0", async function () {
      await expect(
        fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("0")], {
          account: defaultSigner.account,
        })
      ).to.be.rejectedWith("ZeroDeposit()");
    });

    it("should redeem DS : Permit", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("10")]);

      const depositEvents = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);

      const redeemAmount = parseEther("10");
      const permitmsg = await helper.permit({
        amount: redeemAmount,
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        redeemAmount,
        permitmsg,
        deadline,
      ]);

      const event = await fixture.moduleCore.getEvents
        .DsRedeemed({
          dsId: dsId,
          Id: fixture.Id,
          redeemer: defaultSigner.account.address,
        })
        .then((e) => e[0]);

      expect(event.args.received!).to.equal(
        redeemAmount - helper.calculatePrecentage(redeemAmount)
      );
      expect(event.args.fee).to.equal(helper.calculatePrecentage(redeemAmount));
    });

    it("should redeem DS : Approval", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("10")]);

      const depositEvents = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);

      const dsContract = await hre.viem.getContractAt("ERC20", ds!);
      await dsContract.write.approve([
        fixture.moduleCore.address,
        parseEther("10"),
      ]);

      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        parseEther("10"),
      ]);

      const event = await fixture.moduleCore.getEvents.DsRedeemed({
        dsId: dsId,
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem CT : Permit", async function () {
      const redeemAmount = parseEther("5");
      const depositAmount = parseEther("10");
      expiryTime = 100000;

      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, depositAmount]);

      const { dsId, ds, ct, expiry } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, depositAmount], {
        account: defaultSigner.account,
      });

      await time.increaseTo(expiry);

      const msgPermit = await helper.permit({
        amount: redeemAmount,
        deadline,
        erc20contractAddress: ct!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      const [_, raReceivedPreview] =
        await fixture.moduleCore.read.previewRedeemWithCt([
          fixture.Id,
          dsId!,
          redeemAmount,
        ]);

      expect(raReceivedPreview).to.equal(redeemAmount);

      await fixture.moduleCore.write.redeemWithCT([
        fixture.Id,
        dsId!,
        redeemAmount,
        msgPermit,
        deadline,
      ]);

      const event = await fixture.moduleCore.getEvents.CtRedeemed({
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      expect(event[0].args.amount!).to.equal(redeemAmount);
      expect(event[0].args.raReceived!).to.equal(redeemAmount);
    });

    it("should redeem CT : Approval", async function () {
      const redeemAmount = parseEther("5");
      const depositAmount = parseEther("10");
      expiryTime = 100000;

      pa.write.approve([fixture.moduleCore.address, depositAmount]);

      const { dsId, ds, ct, expiry } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, depositAmount], {
        account: defaultSigner.account,
      });

      await time.increaseTo(expiry);

      const ctContract = await hre.viem.getContractAt("ERC20", ct!);
      await ctContract.write.approve([
        fixture.moduleCore.address,
        redeemAmount,
      ]);
      const [_, raReceivedPreview] =
        await fixture.moduleCore.read.previewRedeemWithCt([
          fixture.Id,
          dsId!,
          redeemAmount,
        ]);

      expect(raReceivedPreview).to.equal(redeemAmount);

      await fixture.moduleCore.write.redeemWithCT([
        fixture.Id,
        dsId!,
        redeemAmount,
      ]);

      const event = await fixture.moduleCore.getEvents.CtRedeemed({
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      expect(event[0].args.amount!).to.equal(redeemAmount);
      expect(event[0].args.raReceived!).to.equal(redeemAmount);
    });
  });

  describe("with exchange rate", function () {
    it("should deposit with correct exchange rate", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("10")]);

      const event = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem DS with correct exchange rate", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      // 2 RA
      const rates = parseEther("2");

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000,
        { rates: rates }
      );
      const depositAmount = parseEther("10");
      const expectedAMount = parseEther("5");

      await fixture.moduleCore.write.depositPsm([fixture.Id, depositAmount], {
        account: defaultSigner.account,
      });

      const depositEvents = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);

      const permitmsg = await helper.permit({
        amount: expectedAMount,
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        expectedAMount,
        permitmsg,
        deadline,
      ]);

      const event = await fixture.moduleCore.getEvents.DsRedeemed({
        dsId: dsId,
        Id: fixture.Id,
        redeemer: defaultSigner.account.address,
      });

      expect(event[0].args.dsExchangeRate).to.equal(rates);
      expect(event[0].args.received).to.equal(
        depositAmount - helper.calculatePrecentage(depositAmount)
      );
    });

    it("should get correct preview output", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      // 2 RA
      const rates = parseEther("2");

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000,
        { rates: rates }
      );
      const depositAmount = parseEther("10");
      const expectedAMount = parseEther("5");

      await fixture.moduleCore.write.depositPsm([fixture.Id, depositAmount], {
        account: defaultSigner.account,
      });

      const event = await fixture.moduleCore.getEvents.PsmDeposited({
        depositor: defaultSigner.account.address,
      });

      const raReceived = await fixture.moduleCore.read.previewRedeemRaWithDs([
        fixture.Id,
        dsId!,
        expectedAMount,
      ]);

      expect(raReceived).to.equal(depositAmount);
    });
  });

  describe("cancel position", function () {
    it("should cancel position : Permit", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      mintAmount = parseEther("1");
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000,
        { rates: parseEther("0.5") }
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("1")], {
        account: defaultSigner.account,
      });

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

      const msgPermit1 = await helper.permit({
        amount: parseEther("2"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });
      const msgPermit2 = await helper.permit({
        amount: parseEther("2"),
        deadline,
        erc20contractAddress: ct!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemRaWithCtDs([
        fixture.Id,
        parseEther("2"),
        msgPermit1,
        deadline,
        msgPermit2,
        deadline,
      ]);

      const events = await fixture.moduleCore.getEvents.Cancelled({
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

      expect(raBalance).to.equal(parseEther("1000"));

      const afterDsBalance = await dsContract.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(afterDsBalance).to.equal(parseEther("0"));

      const afterCtBalance = await ctContract.read.balanceOf([
        defaultSigner.account.address,
      ]);

      expect(afterCtBalance).to.equal(parseEther("0"));
    });

    it("should cancel position : Approval", async function () {
      mintAmount = parseEther("1");
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000,
        { rates: parseEther("0.5") }
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("1")], {
        account: defaultSigner.account,
      });

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
        fixture.moduleCore.address,
        parseEther("2"),
      ]);

      await ctContract.write.approve([
        fixture.moduleCore.address,
        parseEther("2"),
      ]);

      await fixture.moduleCore.write.redeemRaWithCtDs([
        fixture.Id,
        parseEther("2"),
      ]);

      const events = await fixture.moduleCore.getEvents.Cancelled({
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

      expect(raBalance).to.equal(parseEther("1000"));

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
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000,
        { rates: parseEther("0.5") }
      );

      const [raAmount, rates] =
        await fixture.moduleCore.read.previewRedeemRaWithCtDs([
          fixture.Id,
          parseEther("2"),
        ]);

      expect(raAmount).to.equal(parseEther("1"));
      expect(rates).to.equal(parseEther("0.5"));
    });
  });

  describe("repurchase", function () {
    it("should repurchase", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 2 RA for every DS
      const rates = parseEther("2");
      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000,
        { rates: rates }
      );

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);

      const depositEvents = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);

      const permitmsg = await helper.permit({
        amount: parseEther("10"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        parseEther("10"),
        permitmsg,
        deadline,
      ]);

      const [availablePa, availableDs] =
        await fixture.moduleCore.read.availableForRepurchase([fixture.Id]);

      expect(availablePa).to.equal(parseEther("10"));
      expect(availableDs).to.equal(parseEther("10"));

      // remember fee rate is fixed at 10%
      const [_, received, feePrecentage, fee, exchangeRate] =
        await fixture.moduleCore.read.previewRepurchase([
          fixture.Id,
          parseEther("2"),
        ]);

      expect(received).to.equal(parseEther("0.95"));
      expect(feePrecentage).to.equal(parseEther("5"));
      expect(fee).to.equal(parseEther("0.1"));
      expect(exchangeRate).to.equal(parseEther("2"));

      await fixture.moduleCore.write.repurchase([fixture.Id, parseEther("2")]);

      const event = await fixture.moduleCore.getEvents
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
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 2 RA for every DS
      const rates = parseEther("2");
      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000,
        { rates: rates }
      );

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);

      const depositEvents = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);

      const permitmsg = await helper.permit({
        amount: parseEther("10"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        parseEther("10"),
        permitmsg,
        deadline,
      ]);

      const [availablePa, availableDs] =
        await fixture.moduleCore.read.availableForRepurchase([fixture.Id]);

      expect(availablePa).to.equal(parseEther("10"));
      expect(availableDs).to.equal(parseEther("10"));

      time.increaseTo(helper.expiry(expiryTime) + 1);

      await expect(
        fixture.moduleCore.write.repurchase([fixture.Id, parseEther("2")])
      ).to.be.rejected;
    });

    it("should allocate PA for CT wthdrawal correctly after repurchase", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 1 RA for every DS
      const rates = parseEther("1");
      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000,
        { rates: rates }
      );

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);

      const depositEvents = await fixture.moduleCore.getEvents.PsmDeposited({
        Id: fixture.Id,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);

      const permitmsg = await helper.permit({
        amount: parseEther("50"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        parseEther("50"),
        permitmsg,
        deadline,
      ]);

      await fixture.moduleCore.write.repurchase([fixture.Id, parseEther("25")]);

      await time.increaseTo(helper.expiry(expiryTime) + 1);

      const [paReceivedPreview, raReceivedPreview] =
        await fixture.moduleCore.read.previewRedeemWithCt([
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
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemWithCT([
        fixture.Id,
        dsId!,
        parseEther("1"),
        permitmsg2,
        deadline2,
      ]);

      const event = await fixture.moduleCore.getEvents
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

    it("repurchase should revert when insufficient liquidity", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 2 RA for every DS
      const rates = parseEther("2");
      await issueNewSwapAssets(helper.nowTimestampInSeconds() + 1000, {
        rates: rates,
      });

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);
      await expect(
        moduleCore.write.repurchase([fixture.Id, parseEther("2")])
      ).to.be.rejectedWith(`InsufficientLiquidity(0, ${parseEther("0.95")})`);
    });
  });

  // @yusak found this, cannot issue new DS on the third time while depositing to LV
  // caused by not actually mint CT + DS at issuance
  it("should be able to issue DS for the third time", async function () {
    mintAmount = parseEther("1000000");

    await fixture.ra.write.mint([defaultSigner.account.address, mintAmount]);
    await fixture.ra.write.approve([fixture.moduleCore.address, mintAmount]);

    const Id = await fixture.moduleCore.read.getId([
      fixture.pa.address,
      fixture.ra.address,
    ]);
    const expiryInterval = 1000;
    let expiry = helper.expiry(expiryInterval);

    for (let i = 0; i < 10; i++) {
      await fixture.config.contract.write.issueNewDs([
        Id,
        BigInt(expiry),
        parseEther("1"),
        parseEther("5"),
      ]);

      const events = await fixture.moduleCore.getEvents.Issued({
        Id,
        expiry: BigInt(expiry),
      });

      await fixture.moduleCore.write.depositLv([Id, parseEther("10")]);

      await fixture.lv.write.approve([
        fixture.moduleCore.address,
        parseEther("10"),
      ]);

      await fixture.moduleCore.write.requestRedemption([Id, parseEther("1")]);

      expect(events.length).to.equal(1);

      await time.increaseTo(expiry);

      expiry = expiry + expiryInterval;
    }
  });

  describe("separate liquidity", function () {
    it("should separate liquidity", async function () {
      mintAmount = parseEther("10000");

      await fixture.ra.write.approve([fixture.moduleCore.address, mintAmount]);

      await helper.mintRa(
        fixture.ra.address,
        defaultSigner.account.address,
        mintAmount
      );

      pa.write.approve([fixture.moduleCore.address, parseEther("10000")]);

      const expiry = helper.expiry(expiryTime);

      await issueNewSwapAssets(expiry);

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("1000"),
      ]);
      await time.increaseTo(expiry);

      const newExpiry = helper.expiry(expiry * 2);

      const { dsId, ct } = await helper.issueNewSwapAssets({
        expiry: newExpiry,
        moduleCore: fixture.moduleCore.address,
        config: fixture.config.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
      });

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("1000"),
      ]);

      const deadline = BigInt(newExpiry * 2);

      const msgPermit = await helper.permit({
        amount: parseEther("100"),
        deadline,
        erc20contractAddress: ct!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await time.increaseTo(newExpiry);

      await fixture.moduleCore.write.redeemWithCT([
        fixture.Id,
        dsId!,
        parseEther("100"),
        msgPermit,
        deadline,
      ]);

      const event = await fixture.moduleCore.getEvents
        .CtRedeemed({
          Id: fixture.Id,
          redeemer: defaultSigner.account.address,
          dsId,
        })
        .then((e) => e[0]);

      // we expect the amount to be 100 because we deposit 1000 on the DS id while having a total
      // of 2000 RA on the PSM including the DS ID before this, so if we get 1/10 of 1000 back from what
      // we deposited on this DS ID, we can consider this a success
      expect(event.args.raReceived!).to.equal(parseEther("100"));
    });
  });

  describe("valueLocked", function () {
    it("valueLocked should work correctly", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000
      );

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("9.987"),
      ]);
      expect(await fixture.moduleCore.read.valueLocked([fixture.Id])).to.equal(
        parseEther("9.987")
      );
    });
  });

  describe("previewDepositPsm", function () {
    it("previewDepositPsm should work correctly", async function () {
      const depositAmount = parseEther("10");
      pa.write.approve([fixture.moduleCore.address, depositAmount]);

      await issueNewSwapAssets(helper.nowTimestampInSeconds() + 10000, {
        rates: parseEther("2"),
      });

      const [ctReceived, dsReceived, _] =
        await fixture.moduleCore.read.previewDepositPsm([
          fixture.Id,
          depositAmount,
        ]);
      expect(ctReceived).to.equal(parseEther("5"));
      expect(dsReceived).to.equal(parseEther("5"));
    });

    it("previewDepositPsm should revert when depositing 0", async function () {
      await expect(
        fixture.moduleCore.read.previewDepositPsm([fixture.Id, parseEther("0")])
      ).to.be.rejectedWith("ZeroDeposit()");
    });
  });

  describe("previewRepurchase", function () {
    it("previewRepurchase should work correctly", async function () {
      // just to buffer
      const deadline = BigInt(helper.expiry(expiryTime));

      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 2 RA for every DS
      const rates = parseEther("2");
      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000,
        { rates: rates }
      );

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);
      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);

      const permitmsg = await helper.permit({
        amount: parseEther("10"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.moduleCore.address,
        signer: defaultSigner,
      });

      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        parseEther("10"),
        permitmsg,
        deadline,
      ]);

      // remember fee rate is fixed at 10%
      const [_, received, feePrecentage, fee, exchangeRate] =
        await fixture.moduleCore.read.previewRepurchase([
          fixture.Id,
          parseEther("2"),
        ]);

      expect(received).to.equal(parseEther("0.95"));
      expect(feePrecentage).to.equal(parseEther("5"));
      expect(fee).to.equal(parseEther("0.1"));
      expect(exchangeRate).to.equal(parseEther("2"));
    });

    it("previewRepurchase should revert when insufficient liquidity", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 2 RA for every DS
      const rates = parseEther("2");
      await issueNewSwapAssets(helper.nowTimestampInSeconds() + 1000, {
        rates: rates,
      });

      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);
      await expect(
        moduleCore.read.previewRepurchase([fixture.Id, parseEther("2")])
      ).to.be.rejectedWith(`InsufficientLiquidity(0, ${parseEther("0.95")})`);
    });
  });

  describe("repurchaseRates", function () {
    it("repurchaseRates should work correctly", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 2 RA for every DS
      const rates = parseEther("2");
      await issueNewSwapAssets(helper.nowTimestampInSeconds() + 1000, {
        rates: rates,
      });
      expect(await moduleCore.read.repurchaseRates([fixture.Id])).to.be.equal(
        rates
      );
      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);
      expect(await moduleCore.read.repurchaseRates([fixture.Id])).to.be.equal(
        rates
      );
    });
  });

  describe("exchangeRate", function () {
    it("exchangeRate should work correctly", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("100")]);

      // 2 RA for every DS
      const rates = parseEther("2");
      await issueNewSwapAssets(helper.nowTimestampInSeconds() + 1000, {
        rates: rates,
      });
      expect(await moduleCore.read.exchangeRate([fixture.Id])).to.be.equal(
        rates
      );
      await fixture.moduleCore.write.depositPsm([
        fixture.Id,
        parseEther("100"),
      ]);
      expect(await moduleCore.read.exchangeRate([fixture.Id])).to.be.equal(
        rates
      );
    });
  });

  describe("availableForRepurchase", function () {
    it("availableForRepurchase should work correctly", async function () {
      pa.write.approve([fixture.moduleCore.address, parseEther("10")]);

      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000
      );

      await fixture.moduleCore.write.depositPsm([fixture.Id, parseEther("10")]);
      let [availablePa, availableDs] =
        await fixture.moduleCore.read.availableForRepurchase([fixture.Id]);

      expect(availablePa).to.equal(0n);
      expect(availableDs).to.equal(0n);
      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);
      await fixture.pa.write.approve([fixture.moduleCore.address, mintAmount]);
      const dsContract = await hre.viem.getContractAt("ERC20", ds!);
      await dsContract.write.approve([
        fixture.moduleCore.address,
        parseEther("10"),
      ]);
      await fixture.moduleCore.write.redeemRaWithDs([
        fixture.Id,
        dsId!,
        parseEther("9.987"),
      ]);
      [availablePa, availableDs] =
        await fixture.moduleCore.read.availableForRepurchase([fixture.Id]);
      expect(availablePa).to.equal(parseEther("9.987"));
      expect(availableDs).to.equal(parseEther("9.987"));
    });
  });
});

// TODO : test redeem ct + ds in 1 scenario, verify the amount is correct!
