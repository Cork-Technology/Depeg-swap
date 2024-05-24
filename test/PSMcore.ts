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
      const psmFixture = await loadFixture(helper.pmCoreWithInitializedPsm);
      const expiry = helper.expiry(10);

      const contract = await hre.viem.getContractAt(
        "PsmCore",
        psmFixture.psmCore.contract.address
      );

      await psmFixture.factory.contract.write.deploySwapAssets([
        psmFixture.ra.address,
        psmFixture.pa.address,
        (await psmFixture.wa).address,
        BigInt(expiry),
      ]);

      const ctDsEvents =
        await psmFixture.factory.contract.getEvents.AssetDeployed({
          wa: psmFixture.wa.address,
        });

      const ct = ctDsEvents[0].args.ct!;
      const ds = ctDsEvents[0].args.ds!;

      const psmId = await contract.read.getId([
        psmFixture.pa.address,
        psmFixture.ra.address,
      ]);
      await contract.write.issueNewDs([psmId, BigInt(expiry), ct, ds], {
        account: defaultSigner.account,
      });

      const events = await contract.getEvents.Issued({
        psmId,
        expiry: BigInt(expiry),
      });

      expect(events.length).to.equal(1);
    });
  });

  describe("commons", function () {
    it("should deposit", async function () {
      const { defaultSigner } = await helper.getSigners();
      const fixture = await loadFixture(helper.pmCoreWithInitializedPsm);
      const mintAmount = parseEther("1000");
      const expTime = 10;

      await fixture.ra.write.approve([
        fixture.psmCore.contract.address,
        mintAmount,
      ]);

      const deadline = BigInt(helper.expiry(expTime));
      console.log("Wa", fixture.wa.address);
      console.log("signer", defaultSigner.account.address);
      console.log("psm", fixture.psmCore.contract.address);
      console.log("factory", fixture.factory.contract.address);
      console.log("pa", fixture.pa.address);
      console.log("ra", fixture.ra.address);

      const waSig = await helper.permit(
        {
          amount: parseEther("100"),
          deadline,
          erc20contractAddress: fixture.wa.address,
          psmAddress: fixture.psmCore.contract.address,
          signer: defaultSigner,
        },
        "WrappedAsset"
      );

      const { dsId } = await helper.issueNewSwapAssets({
        expiry: helper.nowTimestampInSeconds() + 20,
        psmCore: fixture.psmCore.contract.address,
        pa: fixture.pa.address,
        ra: fixture.ra.address,
        factory: fixture.factory.contract.address,
        wa: fixture.wa.address,
      });

      await fixture.psmCore.contract.write.deposit(
        [fixture.psmId, parseEther("100"), waSig, deadline],
        {
          account: defaultSigner.account,
        }
      );

      const event = await fixture.psmCore.contract.getEvents.Deposited({
        psmId: fixture.psmId,
        dsId,
        depositor: defaultSigner.account.address,
      });

      expect(event.length).to.equal(1);
    });

    // it("should redeem DS", async function () {
    //   const mintAmount = parseEther("1000");
    //   const resource = await loadFixture(withDs);
    //   await resource.ra.write.mint([
    //     resource.signer.account.address,
    //     mintAmount,
    //   ]);

    //   await resource.ra.write.approve([resource.psmCore.address, mintAmount]);

    //   await resource.psmCore.write.deposit(
    //     [resource.psmid, parseEther("100")],
    //     {
    //       account: resource.signer.account,
    //     }
    //   );

    //   // just to buffer
    //   const deadline = BigInt(resource.expiry + 10);

    //   const msg = permit(
    //     resource.signer,
    //     resource.dsAddress as Address,
    //     resource.psmCore.address,
    //     parseEther("10"),
    //     deadline
    //   );

    //   const ds = await hre.viem.getContractAt(
    //     "Asset",
    //     resource.dsAddress as Address
    //   );
    //   const psmBalance = await ds.read.balanceOf([resource.psmCore.address]);
    //   const userBalance = await ds.read.balanceOf([
    //     resource.signer.account.address,
    //   ]);

    //   // prepare pa
    //   await resource.pa.write.mint([
    //     resource.signer.account.address,
    //     mintAmount,
    //   ]);

    //   await resource.pa.write.approve([resource.psmCore.address, mintAmount]);

    //   await resource.psmCore.write.redeemWithRaWithDs(
    //     [resource.psmid, resource.dsId, parseEther("10"), await msg, deadline],
    //     {
    //       account: resource.signer.account,
    //     }
    //   );

    //   const event = await resource.psmCore.getEvents.DsRedeemed({
    //     dsId: resource.dsId,
    //     psmId: resource.psmid,
    //     redeemer: resource.signer.account.address,
    //   });

    //   expect(event.length).to.equal(1);
    // });

    // it("should redeem CT", async function () {
    //   const mintAmount = parseEther("1000");
    //   const resource = await loadFixture(withDs);
    //   await resource.ra.write.mint([
    //     resource.signer.account.address,
    //     mintAmount,
    //   ]);

    //   await resource.ra.write.approve([resource.psmCore.address, mintAmount]);

    //   await resource.psmCore.write.deposit(
    //     [resource.psmid, parseEther("100")],
    //     {
    //       account: resource.signer.account,
    //     }
    //   );

    //   // just to buffer
    //   const deadline = BigInt(resource.expiry + 10);

    //   const msg = permit(
    //     resource.signer,
    //     resource.ctAddress as Address,
    //     resource.psmCore.address,
    //     parseEther("3"),
    //     deadline
    //   );

    //   const ct = await hre.viem.getContractAt(
    //     "Asset",
    //     resource.ctAddress as Address
    //   );

    //   const psmBalance = await ct.read.balanceOf([resource.psmCore.address]);
    //   const userBalance = await ct.read.balanceOf([
    //     resource.signer.account.address,
    //   ]);

    //   await time.increaseTo(resource.expiry);

    //   await resource.psmCore.write.redeemWithCT(
    //     [resource.psmid, resource.dsId, parseEther("3"), await msg, deadline],
    //     {
    //       account: resource.signer.account,
    //     }
    //   );

    //   const event = await resource.psmCore.getEvents.CtRedeemed({
    //     psmId: resource.psmid,
    //     redeemer: resource.signer.account.address,
    //   });

    //   console.log(formatEther(event[0].args.amount!));

    //   expect(event.length).to.equal(1);
    // });
  });
});

// TODO : test preview output to be the same as actual function call
// TODO : test redeem ct + ds in 1 scenario, verify the amount is correct!
// TODO : make a gas profiling report.
