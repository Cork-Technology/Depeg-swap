import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, formatEther, parseEther, WalletClient } from "viem";

describe("PSM core", function () {
  function nowTimestampInSeconds() {
    return Math.floor(Date.now() / 1000);
  }

  async function fixture() {
    return await hre.viem.deployContract("PsmCore");
  }

  async function withDs() {
    const signers = await hre.viem.getWalletClients();
    const signer = signers[0];

    const psmCore = await loadFixture(fixture);
    const pa = await hre.viem.deployContract("Asset", ["1", "TKN"], {
      client: {
        wallet: signer,
      },
    });
    const ra = await hre.viem.deployContract("Asset", ["2", "TKN"], {
      client: {
        wallet: signer,
      },
    });

    const pair = await psmCore.write.initialize([pa.address, ra.address], {
      account: signer.account,
    });
    const event = await psmCore.getEvents.Initialized({
      pa: pa.address,
      ra: ra.address,
    });

    const psmid = event[0].args.id!;

    // 1 hour
    const expiry = nowTimestampInSeconds() + 3600;

    const ds = await psmCore.write.issueNewDs([psmid, BigInt(expiry)]);
    const issuedEvent = await psmCore.getEvents.Issued({
      psmId: psmid,
      expiry: BigInt(expiry),
    });

    const dsId = issuedEvent[0].args.dsId!;
    const dsAddress = issuedEvent[0].args.ds;
    const ctAddress = issuedEvent[0].args.ct;

    return {
      psmCore,
      pa,
      ra,
      psmid,
      dsId,
      expiry,
      signer,
      dsAddress,
      ctAddress,
    };
  }

  async function permit(
    signer: WalletClient,
    contractAddress: string,
    psmAddres: string,
    amount: bigint,
    deadline: bigint
  ) {
    const contractName = await (
      await hre.viem.getContractAt("Asset", contractAddress as Address)
    ).read.name();
    const nonces = await (
      await hre.viem.getContractAt("Asset", contractAddress as Address)
    ).read.nonces([signer.account!.address as Address]);

    // set the domain parameters
    const domain = {
      name: contractName,
      version: "1",
      chainId: hre.network.config.chainId!,
      verifyingContract: psmAddres,
    };

    // set the Permit type parameters
    const types = {
      Permit: [
        {
          name: "owner",
          type: "address",
        },
        {
          name: "spender",
          type: "address",
        },
        {
          name: "value",
          type: "uint256",
        },
        {
          name: "nonce",
          type: "uint256",
        },
        {
          name: "deadline",
          type: "uint256",
        },
      ],
    };

    // set the Permit type values
    const values = {
      owner: signer.account!.address,
      spender: psmAddres,
      value: amount,
      nonce: nonces,
      deadline: deadline,
    };

    // sign the Permit type data with the deployer's private key
    return await signer.signTypedData({
      domain: {
        chainId: hre.network.config.chainId!,
        name: contractName,
        verifyingContract: contractAddress as Address,
        version: "1",
      },
      account: signer.account?.address as Address,
      types: types,
      primaryType: "Permit",
      message: values,
    });
  }

  describe("deployment", function () {
    it("Should deploy the PsmCore contract", async function () {
      const psmCore = await loadFixture(fixture);
      expect(psmCore).to.be.ok;
    });
  });

  describe("issue pair", function () {
    it("Should issue a pair", async function () {
      const psmCore = await loadFixture(fixture);
      const pa = await hre.viem.deployContract("Asset", ["1", "TKN"]);
      const ra = await hre.viem.deployContract("Asset", ["2", "TKN"]);

      const pair = await psmCore.write.initialize([pa.address, ra.address]);
      const event = await psmCore.getEvents.Initialized({
        pa: pa.address,
        ra: ra.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should issue new ds", async function () {
      const psmCore = await loadFixture(fixture);
      const pa = await hre.viem.deployContract("Asset", ["1", "TKN"]);
      const ra = await hre.viem.deployContract("Asset", ["2", "TKN"]);

      const pair = await psmCore.write.initialize([pa.address, ra.address]);
      const event = await psmCore.getEvents.Initialized({
        pa: pa.address,
        ra: ra.address,
      });

      const psmid = event[0].args.id!;

      // 1 hour
      const expiry = nowTimestampInSeconds() + 3600;

      const ds = await psmCore.write.issueNewDs([psmid, BigInt(expiry)]);
      const issuedEvent = await psmCore.getEvents.Issued({
        psmId: psmid,
        expiry: BigInt(expiry),
      });

      expect(issuedEvent.length).to.equal(1);
    });
  });

  describe("commons", function () {
    it("should deposit", async function () {
      const mintAmount = parseEther("1000");
      const resource = await loadFixture(withDs);
      await resource.ra.write.mint([
        resource.signer.account.address,
        mintAmount,
      ]);

      await resource.ra.write.approve([resource.psmCore.address, mintAmount]);

      await resource.psmCore.write.deposit(
        [resource.psmid, parseEther("100")],
        {
          account: resource.signer.account,
        }
      );
      const event = await resource.psmCore.getEvents.Deposited({
        depositor: resource.signer.account.address,
        dsId: resource.dsId,
        psmId: resource.psmid,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem DS", async function () {
      const mintAmount = parseEther("1000");
      const resource = await loadFixture(withDs);
      await resource.ra.write.mint([
        resource.signer.account.address,
        mintAmount,
      ]);

      await resource.ra.write.approve([resource.psmCore.address, mintAmount]);

      await resource.psmCore.write.deposit(
        [resource.psmid, parseEther("100")],
        {
          account: resource.signer.account,
        }
      );

      // just to buffer
      const deadline = BigInt(resource.expiry + 10);

      const msg = permit(
        resource.signer,
        resource.dsAddress as Address,
        resource.psmCore.address,
        parseEther("10"),
        deadline
      );

      const ds = await hre.viem.getContractAt(
        "Asset",
        resource.dsAddress as Address
      );
      const psmBalance = await ds.read.balanceOf([resource.psmCore.address]);
      const userBalance = await ds.read.balanceOf([
        resource.signer.account.address,
      ]);

      // prepare pa
      await resource.pa.write.mint([
        resource.signer.account.address,
        mintAmount,
      ]);

      await resource.pa.write.approve([resource.psmCore.address, mintAmount]);

      await resource.psmCore.write.redeemWithRaWithDs(
        [resource.psmid, resource.dsId, parseEther("10"), await msg, deadline],
        {
          account: resource.signer.account,
        }
      );

      const event = await resource.psmCore.getEvents.DsRedeemed({
        dsId: resource.dsId,
        psmId: resource.psmid,
        redeemer: resource.signer.account.address,
      });

      expect(event.length).to.equal(1);
    });

    it("should redeem CT", async function () {
      const mintAmount = parseEther("1000");
      const resource = await loadFixture(withDs);
      await resource.ra.write.mint([
        resource.signer.account.address,
        mintAmount,
      ]);

      await resource.ra.write.approve([resource.psmCore.address, mintAmount]);

      await resource.psmCore.write.deposit(
        [resource.psmid, parseEther("100")],
        {
          account: resource.signer.account,
        }
      );

      // just to buffer
      const deadline = BigInt(resource.expiry + 10);

      const msg = permit(
        resource.signer,
        resource.ctAddress as Address,
        resource.psmCore.address,
        parseEther("3"),
        deadline
      );

      const ct = await hre.viem.getContractAt(
        "Asset",
        resource.ctAddress as Address
      );

      const psmBalance = await ct.read.balanceOf([resource.psmCore.address]);
      const userBalance = await ct.read.balanceOf([
        resource.signer.account.address,
      ]);

      await time.increaseTo(resource.expiry);

      await resource.psmCore.write.redeemWithCT(
        [resource.psmid, resource.dsId, parseEther("3"), await msg, deadline],
        {
          account: resource.signer.account,
        }
      );

      const event = await resource.psmCore.getEvents.CtRedeemed({
        psmId: resource.psmid,
        redeemer: resource.signer.account.address,
      });

      console.log(formatEther(event[0].args.amount!));

      expect(event.length).to.equal(1);
    });
  });
});

// TODO : test preview output to be the same as actual function call
// TODO : test redeem ct + ds in 1 scenario, verify the amount is correct!
// TODO : make a gas profiling report.
