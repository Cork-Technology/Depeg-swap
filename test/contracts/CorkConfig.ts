import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { Address, parseEther, parseUnits, zeroAddress } from "viem";
import * as helper from "../helper/TestHelper";

describe("CorkConfig", function () {
  let {
    defaultSigner,
    secondSigner,
    signers,
  }: ReturnType<typeof helper.getSigners> = {} as any;

  let expiryTime: number;
  let mintAmount: bigint;

  let fixture: Awaited<
    ReturnType<typeof helper.ModuleCoreWithInitializedPsmLv>
  >;

  let moduleCore: Awaited<ReturnType<typeof getModuleCore>>;
  let corkConfig: Awaited<ReturnType<typeof getCorkConfig>>;
  let pa: Awaited<ReturnType<typeof getPA>>;
  
  const initialDsPrice = parseEther("0.1");

  let Id: Awaited<ReturnType<typeof moduleCore.read.getId>>;

  const getModuleCore = async (address: Address) => {
    return await hre.viem.getContractAt("ModuleCore", address);
  };

  const getCorkConfig = async (address: Address) => {
    return await hre.viem.getContractAt("CorkConfig", address);
  };

  const getPA = async (address: Address) => {
    return await hre.viem.getContractAt("ERC20", address);
  };

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

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, secondSigner, signers } = helper.getSigners(__signers));
  });

  beforeEach(async () => {
    fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);

    moduleCore = await getModuleCore(fixture.moduleCore.address);
    corkConfig = await getCorkConfig(fixture.config.contract.address);

    expiryTime = helper.expiry(1e18 * 1000);
    mintAmount = parseEther("1000");

    await fixture.ra.write.approve([fixture.moduleCore.address, mintAmount]);

    await helper.mintRa(
      fixture.ra.address,
      defaultSigner.account.address,
      mintAmount
    );

    pa = await getPA(fixture.pa.address);
    Id = await moduleCore.read.getId([fixture.pa.address, fixture.ra.address]);
  });

  it("should deploy correctly", async function () {
    corkConfig = await hre.viem.deployContract("CorkConfig", [], {
      client: {
        wallet: defaultSigner,
      },
    });
    expect(corkConfig).to.be.ok;
    expect(
      await corkConfig.read.hasRole([
        await corkConfig.read.DEFAULT_ADMIN_ROLE(),
        defaultSigner.account.address,
      ])
    ).to.be.equals(true);
    expect(
      await corkConfig.read.hasRole([
        await corkConfig.read.MANAGER_ROLE(),
        defaultSigner.account.address,
      ])
    ).to.be.equals(false);
    expect(await corkConfig.read.paused()).to.be.equals(false);
  });

  describe("SetModuleCore", function () {
    it("setModuleCore should work correctly", async function () {
      expect(await corkConfig.read.moduleCore()).to.not.be.equals(
        defaultSigner.account.address
      );
      await expect(
        await corkConfig.write.setModuleCore([secondSigner.account.address], {
          account: defaultSigner.account,
        })
      ).to.be.ok;
      expect(
        await (await corkConfig.read.moduleCore()).toLowerCase()
      ).to.be.equals(secondSigner.account.address);
    });

    it("Revert when passed zero address to setModuleCore", async function () {
      await expect(
        corkConfig.write.setModuleCore([zeroAddress], {
          account: defaultSigner.account,
        })
      ).to.be.rejectedWith("InvalidAddress()");
    });

    it("Revert when non MANAGER call setModuleCore", async function () {
      await expect(
        corkConfig.write.setModuleCore([defaultSigner.account.address], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("initializeModuleCore", function () {
    it("initializeModuleCore should work correctly", async function () {
      const { pa, ra } = await loadFixture(helper.backedAssets);
      await expect(
        await corkConfig.write.initializeModuleCore(
          [pa.address, ra.address, fixture.lvFee, initialDsPrice],
          {
            account: defaultSigner.account,
          }
        )
      ).to.be.ok;
    });

    it("Revert when non MANAGER call initializeModuleCore", async function () {
      await expect(
        corkConfig.write.initializeModuleCore(
          [pa.address, fixture.ra.address, fixture.lvFee, initialDsPrice],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("issueNewDs", function () {
    it("issueNewDs should work correctly", async function () {
      await expect(
        await corkConfig.write.issueNewDs(
          [Id, BigInt(expiryTime), parseEther("1"), parseEther("5")],
          {
            account: defaultSigner.account,
          }
        )
      ).to.be.ok;
    });

    it("Revert issueNewDs when contract is paused", async function () {
      await corkConfig.write.pause({
        account: defaultSigner.account,
      });

      await expect(
        corkConfig.write.issueNewDs(
          [Id, BigInt(expiryTime), parseEther("1"), parseEther("10")],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith("EnforcedPause()");
    });

    it("Revert when repurchaseFeePercentage is more than 5%", async function () {
      await expect(
        corkConfig.write.issueNewDs([
          Id,
          BigInt(expiryTime),
          parseEther("1"),
          parseEther("5.00000001"),
        ])
      ).to.be.rejectedWith("InvalidFees()");
    });

    it("Revert when non MANAGER call issueNewDs", async function () {
      await expect(
        corkConfig.write.issueNewDs(
          [Id, BigInt(expiryTime), parseEther("1"), parseEther("10")],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("updateRepurchaseFeeRate", function () {
    it("updateRepurchaseFeeRate should work correctly", async function () {
      expect(await moduleCore.read.repurchaseFee([Id])).to.be.equals(
        parseUnits("0", 1)
      );
      expect(
        await corkConfig.write.updateRepurchaseFeeRate([Id, 1000n], {
          account: defaultSigner.account,
        })
      ).to.be.ok;
      expect(await moduleCore.read.repurchaseFee([Id])).to.be.equals(
        parseUnits("1000", 0)
      );
    });

    it("Revert when non MANAGER call updateRepurchaseFeeRate", async function () {
      await expect(
        corkConfig.write.updateRepurchaseFeeRate([Id, 1000n], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("updateEarlyRedemptionFeeRate", function () {
    it("updateEarlyRedemptionFeeRate should work correctly", async function () {
      expect(await moduleCore.read.earlyRedemptionFee([Id])).to.be.equals(
        parseEther("5")
      );
      expect(
        await corkConfig.write.updateEarlyRedemptionFeeRate([Id, 1000n], {
          account: defaultSigner.account,
        })
      ).to.be.ok;
      expect(await moduleCore.read.earlyRedemptionFee([Id])).to.be.equals(
        parseUnits("1000", 0)
      );
    });

    it("Revert when non MANAGER call updateEarlyRedemptionFeeRate", async function () {
      await expect(
        corkConfig.write.updateEarlyRedemptionFeeRate([Id, 1000n], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("updatePsmBaseRedemptionFeePrecentage", function () {
    it("updatePsmBaseRedemptionFeePrecentage should work correctly", async function () {
      expect(await moduleCore.read.baseRedemptionFee()).to.be.equals(
        parseEther("5")
      );
      expect(
        await corkConfig.write.updatePsmBaseRedemptionFeePrecentage([1000n], {
          account: defaultSigner.account,
        })
      ).to.be.ok;
      expect(await moduleCore.read.baseRedemptionFee()).to.be.equals(
        parseUnits("1000", 0)
      );
    });

    it("Revert when non MANAGER call updatePsmBaseRedemptionFeePrecentage", async function () {
      await expect(
        corkConfig.write.updatePsmBaseRedemptionFeePrecentage([1000n], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("updatePoolsStatus", function () {
    it("updatePoolsStatus should work correctly", async function () {
      const depositAmount = parseEther("10");
      pa.write.approve([fixture.moduleCore.address, depositAmount]);
      const { dsId } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 10000
      );
      await fixture.moduleCore.write.depositPsm([fixture.Id, depositAmount]);

      expect(
        await corkConfig.write.updatePoolsStatus([Id, true, true, true, true], {
          account: defaultSigner.account,
        })
      ).to.be.ok;

      await expect(
        fixture.moduleCore.write.depositPsm([fixture.Id, depositAmount])
      ).to.be.rejectedWith("PSMDepositPaused()");

      await expect(
        fixture.moduleCore.write.redeemRaWithDs([
          fixture.Id,
          dsId!,
          depositAmount,
        ])
      ).to.be.rejectedWith("PSMWithdrawalPaused()");

      await expect(
        fixture.moduleCore.write.redeemWithCT([
          fixture.Id,
          dsId!,
          depositAmount,
        ])
      ).to.be.rejectedWith("PSMWithdrawalPaused()");

      await expect(
        fixture.moduleCore.write.redeemRaWithCtDs([fixture.Id, parseEther("2")])
      ).to.be.rejectedWith("PSMWithdrawalPaused()");

      await expect(
        fixture.moduleCore.write.depositLv([fixture.Id, parseEther("2")])
      ).to.be.rejectedWith("LVDepositPaused()");

      await expect(
        fixture.moduleCore.write.requestRedemption([Id, depositAmount])
      ).to.be.rejectedWith("LVWithdrawalPaused()");

      await expect(
        fixture.moduleCore.write.redeemExpiredLv([
          fixture.Id,
          secondSigner.account.address,
          depositAmount + BigInt(1),
        ])
      ).to.be.rejectedWith("LVWithdrawalPaused()");

      await expect(
        fixture.moduleCore.write.redeemEarlyLv([
          fixture.Id,
          defaultSigner.account.address,
          parseEther("1"),
        ])
      ).to.be.rejectedWith("LVWithdrawalPaused()");
    });

    it("Revert when non MANAGER call updatePoolsStatus", async function () {
      await expect(
        corkConfig.write.updatePoolsStatus([Id, false, false, false, false], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("Pause", function () {
    it("pause should work correctly", async function () {
      expect(await corkConfig.read.paused()).to.be.equals(false);

      await expect(
        await corkConfig.write.pause({
          account: defaultSigner.account,
        })
      ).to.be.ok;

      expect(await corkConfig.read.paused()).to.be.equals(true);
    });

    it("Revert when non MANAGER call pause", async function () {
      await expect(
        corkConfig.write.pause({
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("Unpause", function () {
    it("unpause should work correctly", async function () {
      await corkConfig.write.pause();

      expect(await corkConfig.read.paused()).to.be.equals(true);

      await expect(
        await corkConfig.write.unpause({
          account: defaultSigner.account,
        })
      ).to.be.ok;

      expect(await corkConfig.read.paused()).to.be.equals(false);
    });

    it("Revert when non MANAGER call unpause", async function () {
      await expect(
        corkConfig.write.unpause({
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });
});
