import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "./helper/TestHelper";

describe("PSM core", function () {
  describe("issue pair", function () {
    it("should issue new ds", async function () {
      const { defaultSigner } = await helper.getSigners();
      const psmFixture = await loadFixture(helper.ModuleCoreWithInitializedPsm);
      const expiry = helper.expiry(10);

      const contract = await hre.viem.getContractAt(
        "ModuleCore",
        psmFixture.psmCore.contract.address
      );

      await psmFixture.factory.contract.write.deploySwapAssets([
        psmFixture.ra.address,
        psmFixture.pa.address,
        psmFixture.wa.address,
        psmFixture.psmCore.contract.address,
        BigInt(expiry),
      ]);

      const ctDsEvents =
        await psmFixture.factory.contract.getEvents.AssetDeployed({
          wa: psmFixture.wa.address,
        });

      const ct = ctDsEvents[0].args.ct!;
      const ds = ctDsEvents[0].args.ds!;

      const ModuleId = await contract.read.getId([
        psmFixture.pa.address,
        psmFixture.ra.address,
      ]);

      await contract.write.issueNewDs([ModuleId, BigInt(expiry), ct, ds], {
        account: defaultSigner.account,
      });

      const events = await contract.getEvents.Issued({
        ModuleId,
        expiry: BigInt(expiry),
      });

      expect(events.length).to.equal(1);
    });
  });

  describe("commons", function () {
    it("should deposit", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsm);
      const mintAmount = parseEther("1000");
      const expTime = 10000;

      await fixture.ra.write.approve([
        fixture.psmCore.contract.address,
        mintAmount,
      ]);

      await helper.mintRa(
        fixture.ra.address,
        defaultSigner.account.address,
        mintAmount
      );

      (await hre.viem.getContractAt("ERC20", fixture.pa.address)).write.approve(
        [fixture.psmCore.contract.address, parseEther("10")]
      );

      const { dsId } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 10000,
        psmCore: fixture.psmCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        wa: fixture.wa.address,
      });

      await fixture.psmCore.contract.write.depositPsm(
        [fixture.ModuleId, parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.psmCore.contract.getEvents.PsmDeposited({
        ModuleId: fixture.ModuleId,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem DS", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsm);
      const mintAmount = parseEther("1000");
      const expTime = 10000;

      await fixture.ra.write.approve([
        fixture.psmCore.contract.address,
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
        [fixture.psmCore.contract.address, parseEther("10")]
      );

      const { dsId, ds, ct } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 1000,
        psmCore: fixture.psmCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        wa: fixture.wa.address,
      });

      await fixture.psmCore.contract.write.depositPsm(
        [fixture.ModuleId, parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

      const depositEvents =
        await fixture.psmCore.contract.getEvents.PsmDeposited({
          ModuleId: fixture.ModuleId,
          dsId,
          depositor: defaultSigner.account.address,
        });

      expect(depositEvents.length).to.equal(1);

      // prepare pa
      await fixture.pa.write.mint([defaultSigner.account.address, mintAmount]);

      await fixture.pa.write.approve([
        fixture.psmCore.contract.address,
        mintAmount,
      ]);

      const permitmsg = await helper.permit({
        amount: parseEther("10"),
        deadline,
        erc20contractAddress: ds!,
        psmAddress: fixture.psmCore.contract.address,
        signer: defaultSigner,
      });

      const lockedBalance = await fixture.psmCore.contract.read.valueLocked([
        fixture.ModuleId,
      ]);

      console.log("locked balance", formatEther(lockedBalance));

      await fixture.psmCore.contract.write.redeemRaWithDs(
        [fixture.ModuleId, dsId!, parseEther("10"), permitmsg, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.psmCore.contract.getEvents.DsRedeemed({
        dsId: dsId,
        ModuleId: fixture.ModuleId,
        redeemer: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem CT", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.ModuleCoreWithInitializedPsm);
      const mintAmount = parseEther("1000");
      const expTime = 100000;

      await fixture.ra.write.approve([
        fixture.psmCore.contract.address,
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
        [fixture.psmCore.contract.address, parseEther("10")]
      );

      const { dsId, ds, ct, expiry } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 10000,
        psmCore: fixture.psmCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        wa: fixture.wa.address,
      });

      await fixture.psmCore.contract.write.depositPsm(
        [fixture.ModuleId, parseEther("10")],
        {
          account: defaultSigner.account,
        }
      );

      await time.increaseTo(expiry);

      const msgPermit = await helper.permit({
        amount: parseEther("10"),
        deadline,
        erc20contractAddress: ct!,
        psmAddress: fixture.psmCore.contract.address,
        signer: defaultSigner,
      });

      await fixture.psmCore.contract.write.redeemWithCT(
        [fixture.ModuleId, dsId!, parseEther("10"), msgPermit, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.psmCore.contract.getEvents.CtRedeemed({
        ModuleId: fixture.ModuleId,
        redeemer: defaultSigner.account.address,
      });

      console.log(formatEther(event[0].args.amount!));

      expect(event.length).to.equal(1);
    });
  });
});

// TODO : test preview output to be the same as actual function call
// TODO : test redeem ct + ds in 1 scenario, verify the amount is correct!
// TODO : make a gas profiling report.
