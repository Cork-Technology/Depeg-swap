import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import { ethers } from "ethers";
import hre from "hardhat";
import {
  Address,
  formatEther,
  parseEther,
  WalletClient,
  zeroAddress,
} from "viem";
import * as helper from "../helper/TestHelper";

describe("Module Core", function () {
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
  const initialDsPrice = parseEther("0.1");

  const getModuleCore = async (address: Address) => {
    return await hre.viem.getContractAt("ModuleCore", address);
  };

  const getCorkConfig = async (address: Address) => {
    return await hre.viem.getContractAt("CorkConfig", address);
  };

  const getDs = async (address: Address) => {
    return await hre.viem.getContractAt("Asset", address);
  };

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

  it("should deploy", async function () {
    const mathLib = await hre.viem.deployContract("MathHelper");
    const psm = await hre.viem.deployContract("PsmLibrary", [], {
      libraries: {
        MathHelper: mathLib.address,
      },
    });
    const vault = await hre.viem.deployContract("VaultLibrary", [], {
      libraries: {
        MathHelper: mathLib.address,
      },
    });

    const config = await helper.deployCorkConfig();
    const dsFlashSwapRouter = await helper.deployFlashSwapRouter(
      mathLib.address,
      config.contract.address
    );
    const univ2Factory = await helper.deployUniV2Factory(
      dsFlashSwapRouter.contract.address
    );
    const weth = await helper.deployWeth();
    const univ2Router = await helper.deployUniV2Router(
      weth.contract.address,
      univ2Factory,
      dsFlashSwapRouter.contract.address
    );
    const swapAssetFactory = await helper.deployAssetFactory();

    const moduleCoreContract = await hre.viem.deployContract("ModuleCore", [], {
      client: {
        wallet: defaultSigner,
      },
      libraries: {
        VaultLibrary: vault.address,
        PsmLibrary: psm.address,
      },
    });

    const initializeData =
      "0x1459457a" +
      [
        swapAssetFactory.contract.address,
        univ2Factory,
        dsFlashSwapRouter.contract.address,
        univ2Router,
        config.contract.address,
      ]
        .map((address) => address.slice(2).padStart(64, "0"))
        .join(""); // Remove `0x` and pad each address to 32 bytes

    const moduleCoreProxy = await hre.viem.deployContract(
      "ERC1967Proxy",
      [moduleCoreContract.address, initializeData],
      {}
    );

    const moduleCore = await hre.viem.getContractAt(
      "ModuleCore",
      moduleCoreProxy.address
    );
    expect(moduleCore).to.be.ok;
  });

  it("getId should work correctly", async function () {
    let Id = await moduleCore.read.getId([
      fixture.pa.address,
      fixture.ra.address,
    ]);
    const expectedKey = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ["address", "address"],
        [fixture.pa.address, fixture.ra.address]
      )
    );
    expect(Id).to.equal(expectedKey);
  });

  describe("initialize", function () {
    function encodeModuleCoreInitializeData(
      swapAssetFactoryAddress: Address,
      univ2FactoryAddress: Address,
      flashSwapRouterAddress: Address,
      univ2RouterAddress: Address,
      configAddress: Address
    ) {
      // Step 1: Function selector for `initialize(address,address,address,address,address)`
      const functionSelector = "0x1459457a"; // Keccak-256 hash of `initialize(address,address,address,address,address)` and take the first 4 bytes

      // Step 2: Remove `0x` prefix from each address and pad each address to 32 bytes
      const encodedAddresses = [
        swapAssetFactoryAddress,
        univ2FactoryAddress,
        flashSwapRouterAddress,
        univ2RouterAddress,
        configAddress,
      ]
        .map((address) => address.slice(2).padStart(64, "0")) // Remove `0x` and pad to 64 hex characters (32 bytes)
        .join(""); // Join all addresses into a single string

      // Step 3: Concatenate function selector and encoded addresses
      const initializeData = functionSelector + encodedAddresses;

      return initializeData;
    }

    it("initialize should revert when passed Zero Addresses", async function () {
      const mathLib = await hre.viem.deployContract("MathHelper");
      const psm = await hre.viem.deployContract("PsmLibrary", [], {
        libraries: {
          MathHelper: mathLib.address,
        },
      });
      const vault = await hre.viem.deployContract("VaultLibrary", [], {
        libraries: {
          MathHelper: mathLib.address,
        },
      });
      const moduleCore1 = await hre.viem.deployContract("ModuleCore", [], {
        client: {
          wallet: defaultSigner,
        },
        libraries: {
          VaultLibrary: vault.address,
          PsmLibrary: psm.address,
        },
      });
      let initializeData = encodeModuleCoreInitializeData(
        zeroAddress,
        defaultSigner.account.address,
        defaultSigner.account.address,
        defaultSigner.account.address,
        defaultSigner.account.address
      );
      await expect(
        hre.viem.deployContract("ERC1967Proxy", [
          moduleCore1.address,
          initializeData,
        ])
      ).to.be.rejectedWith("ZeroAddress()");

      initializeData = encodeModuleCoreInitializeData(
        defaultSigner.account.address,
        zeroAddress,
        defaultSigner.account.address,
        defaultSigner.account.address,
        defaultSigner.account.address
      );

      await expect(
        hre.viem.deployContract("ERC1967Proxy", [
          moduleCore1.address,
          initializeData,
        ])
      ).to.be.rejectedWith("ZeroAddress()");

      initializeData = encodeModuleCoreInitializeData(
        defaultSigner.account.address,
        defaultSigner.account.address,
        zeroAddress,
        defaultSigner.account.address,
        defaultSigner.account.address
      );
      await expect(
        hre.viem.deployContract("ERC1967Proxy", [
          moduleCore1.address,
          initializeData,
        ])
      ).to.be.rejectedWith("ZeroAddress()");

      initializeData = encodeModuleCoreInitializeData(
        defaultSigner.account.address,
        defaultSigner.account.address,
        defaultSigner.account.address,
        zeroAddress,
        defaultSigner.account.address
      );
      await expect(
        hre.viem.deployContract("ERC1967Proxy", [
          moduleCore1.address,
          initializeData,
        ])
      ).to.be.rejectedWith("ZeroAddress()");

      initializeData = encodeModuleCoreInitializeData(
        defaultSigner.account.address,
        defaultSigner.account.address,
        defaultSigner.account.address,
        defaultSigner.account.address,
        zeroAddress
      );
      await expect(
        hre.viem.deployContract("ERC1967Proxy", [
          moduleCore1.address,
          initializeData,
        ])
      ).to.be.rejectedWith("ZeroAddress()");
    });
  });

  describe("initializeModuleCore", function () {
    it("initializeModuleCore should work correctly", async function () {
      const { pa, ra } = await helper.backedAssets();
      const expectedId = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "address"],
          [pa.address, ra.address]
        )
      ) as `0x${string}`;

      await corkConfig.write.initializeModuleCore([
        pa.address,
        ra.address,
        fixture.lvFee,
        initialDsPrice,
        parseEther("5"),
      ]);
      const events = await moduleCore.getEvents.InitializedModuleCore({
        id: expectedId,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.id).to.equal(expectedId);
      expect(events[0].args.pa!.toUpperCase()).to.equal(
        pa.address.toUpperCase()
      );
      expect(events[0].args.ra!.toUpperCase()).to.equal(
        ra.address.toUpperCase()
      );
      expect(events[0].args.lv!.toUpperCase()).not.equal(
        zeroAddress.toUpperCase()
      );
    });

    it("initialize should revert when AlreadyInitialized", async function () {
      await expect(
        corkConfig.write.initializeModuleCore([
          fixture.pa.address,
          fixture.ra.address,
          fixture.lvFee,
          initialDsPrice,
          parseEther("5"),
        ])
      ).to.be.rejectedWith("AlreadyInitialized()");
    });

    it("initialize should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.initializeModuleCore([
          fixture.pa.address,
          fixture.ra.address,
          fixture.lvFee,
          initialDsPrice,
          parseEther("5"),
        ])
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("issueNewDs", function () {
    it("issueNewDs should work correctly", async function () {
      await corkConfig.write.issueNewDs([
        fixture.Id,
        BigInt(expiryTime),
        parseEther("1"),
        parseEther("5"),
        parseEther("1"),
        10n,
        BigInt(helper.expiry(1000000)),
      ]);
      const events = await moduleCore.getEvents.Issued({
        Id: fixture.Id,
      });
      const assets = await moduleCore.read.swapAsset([fixture.Id, 1n]);
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.dsId).to.equal(1n);
      expect(events[0].args.expiry).to.equal(BigInt(expiryTime));
      expect(events[0].args.ds).to.equal(assets[1]);
      expect(events[0].args.ct).to.equal(assets[0]);

      let ds = await getDs(assets[1]);
      expect(await ds.read.dsId()).to.equal(1n);
    });

    it("initialize should revert when AlreadyInitialized", async function () {
      const { pa, ra } = await helper.backedAssets();
      const expectedId = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "address"],
          [pa.address, ra.address]
        )
      ) as `0x${string}`;
      await expect(
        corkConfig.write.issueNewDs([
          expectedId,
          BigInt(expiryTime),
          parseEther("1"),
          parseEther("10"),
          parseEther("1"),
          10n,
          BigInt(helper.expiry(1000000)),
        ])
      ).to.be.rejectedWith("Uinitialized()");
    });

    it("issueNewDs should revert when new repurchase fee are more than 5%", async function () {
      await expect(
        corkConfig.write.issueNewDs([
          fixture.Id,
          BigInt(expiryTime),
          parseEther("1"),
          parseEther("5.000000000001"),
          parseEther("1"),
          10n,
          BigInt(helper.expiry(1000000)),
        ])
      ).to.be.rejectedWith("InvalidFees()");
    });

    it("issueNewDs should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.issueNewDs([
          fixture.Id,
          BigInt(expiryTime),
          parseEther("1"),
          parseEther("10"),
          parseEther("1"),
          10n,
          BigInt(helper.expiry(1000000)),
        ])
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("updateRepurchaseFeeRate", function () {
    it("updateRepurchaseFeeRate should work correctly", async function () {
      expect(await moduleCore.read.repurchaseFee([fixture.Id])).to.be.equals(
        0n
      );
      await corkConfig.write.updateRepurchaseFeeRate([fixture.Id, 10011n], {
        account: defaultSigner.account,
      });
      const events = await moduleCore.getEvents.RepurchaseFeeRateUpdated({
        Id: fixture.Id,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.repurchaseFeeRate).to.equal(10011n);
      expect(await moduleCore.read.repurchaseFee([fixture.Id])).to.be.equals(
        10011n
      );
    });

    it("updateRepurchaseFeeRate should revert when new value is more than 5%", async function () {
      await expect(
        corkConfig.write.updateRepurchaseFeeRate([
          fixture.Id,
          parseEther("5.0000000000001"),
        ])
      ).to.be.rejectedWith("InvalidFees()");
    });

    it("updateRepurchaseFeeRate should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updateRepurchaseFeeRate([fixture.Id, 1000n], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("updateEarlyRedemptionFeeRate", function () {
    it("updateEarlyRedemptionFeeRate should work correctly", async function () {
      expect(
        await moduleCore.read.earlyRedemptionFee([fixture.Id])
      ).to.be.equals(parseEther("5"));
      await corkConfig.write.updateEarlyRedemptionFeeRate(
        [fixture.Id, 10011n],
        {
          account: defaultSigner.account,
        }
      );
      const events = await moduleCore.getEvents.EarlyRedemptionFeeRateUpdated({
        Id: fixture.Id,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.earlyRedemptionFeeRate).to.equal(10011n);
      expect(
        await moduleCore.read.earlyRedemptionFee([fixture.Id])
      ).to.be.equals(10011n);
    });

    it("updateEarlyRedemptionFeeRate should revert when new value is more than 5%", async function () {
      await expect(
        corkConfig.write.updateEarlyRedemptionFeeRate([
          fixture.Id,
          parseEther("5.00000000000001"),
        ])
      ).to.be.rejectedWith("InvalidFees()");
    });

    it("updateEarlyRedemptionFeeRate should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updateEarlyRedemptionFeeRate([fixture.Id, 1000n], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("updatePsmDepositsStatus", function () {
    it("updatePsmDepositsStatus should work correctly", async function () {
      await corkConfig.write.updatePsmDepositsStatus([fixture.Id, true]);
      const events = await moduleCore.getEvents.PsmDepositsStatusUpdated({
        Id: fixture.Id,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.isPSMDepositPaused).to.equal(true);
    });

    it("updatePsmDepositsStatus should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updatePsmDepositsStatus([fixture.Id, true], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("updatePsmWithdrawalsStatus", function () {
    it("updatePsmWithdrawalsStatus should work correctly", async function () {
      await corkConfig.write.updatePsmWithdrawalsStatus([fixture.Id, true]);
      const events = await moduleCore.getEvents.PsmWithdrawalsStatusUpdated({
        Id: fixture.Id,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.isPSMWithdrawalPaused).to.equal(true);
    });

    it("updatePsmWithdrawalsStatus should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updatePsmWithdrawalsStatus([fixture.Id, true], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("updatePsmRepurchasesStatus", function () {
    it("updatePsmRepurchasesStatus should work correctly", async function () {
      await corkConfig.write.updatePsmRepurchasesStatus([fixture.Id, true]);
      const events = await moduleCore.getEvents.PsmRepurchasesStatusUpdated({
        Id: fixture.Id,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.isPSMRepurchasePaused).to.equal(true);
    });

    it("updatePsmRepurchasesStatus should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updatePsmRepurchasesStatus([fixture.Id, true], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("updateLvDepositsStatus", function () {
    it("updateLvDepositsStatus should work correctly", async function () {
      await corkConfig.write.updateLvDepositsStatus([fixture.Id, true]);
      const events = await moduleCore.getEvents.LvDepositsStatusUpdated({
        Id: fixture.Id,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.isLVDepositPaused).to.equal(true);
    });

    it("updateLvDepositsStatus should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updateLvDepositsStatus([fixture.Id, true], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("updateLvWithdrawalsStatus", function () {
    it("updateLvWithdrawalsStatus should work correctly", async function () {
      await corkConfig.write.updateLvWithdrawalsStatus([fixture.Id, true]);
      const events = await moduleCore.getEvents.LvWithdrawalsStatusUpdated({
        Id: fixture.Id,
      });
      expect(events.length).to.equal(1);
      expect(events[0].args.Id).to.equal(fixture.Id);
      expect(events[0].args.isLVWithdrawalPaused).to.equal(true);
    });

    it("updateLvWithdrawalsStatus should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updateLvWithdrawalsStatus([fixture.Id, true], {
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("lastDsId", function () {
    it("lastDsId should work correctly", async function () {
      expect(await moduleCore.read.lastDsId([fixture.Id])).to.equal(0n);
      await corkConfig.write.issueNewDs([
        fixture.Id,
        BigInt(expiryTime),
        parseEther("1"),
        parseEther("5"),
        parseEther("1"),
        10n,
        BigInt(helper.expiry(1000000)),
      ]);
      expect(await moduleCore.read.lastDsId([fixture.Id])).to.equal(1n);
    });
  });

  describe("underlyingAsset", function () {
    it("underlyingAsset should work correctly", async function () {
      const key = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["address", "address"],
          [fixture.pa.address, fixture.ra.address]
        )
      ) as `0x${string}`;
      let assets = await moduleCore.read.underlyingAsset([key]);
      expect(assets[1].toUpperCase()).to.equal(
        fixture.pa.address.toUpperCase()
      );
      expect(assets[0].toUpperCase()).to.equal(
        fixture.ra.address.toUpperCase()
      );
    });
  });

  describe("swapAsset", function () {
    it("swapAsset should work correctly", async function () {
      const { dsId, ds, ct } = await issueNewSwapAssets(
        helper.nowTimestampInSeconds() + 1000
      );
      let assets = await moduleCore.read.swapAsset([fixture.Id, dsId!]);
      expect(assets[0].toUpperCase()).to.equal(ct!.toUpperCase());
      expect(assets[1].toUpperCase()).to.equal(ds!.toUpperCase());
    });
  });

  describe("updatePsmBaseRedemptionFeePercentage", function () {
    it("updatePsmBaseRedemptionFeePercentage should work correctly", async function () {
      expect(await moduleCore.read.baseRedemptionFee([fixture.Id])).to.equal(
        parseEther("5")
      );
      await corkConfig.write.updatePsmBaseRedemptionFeePercentage([
        fixture.Id,
        500n,
      ]);
      expect(await moduleCore.read.baseRedemptionFee([fixture.Id])).to.equal(
        500n
      );
    });

    it("updatePsmBaseRedemptionFeePercentage should revert when new value is more than 5%", async function () {
      await expect(
        corkConfig.write.updatePsmBaseRedemptionFeePercentage([
          fixture.Id,
          parseEther("5.00000000000001"),
        ])
      ).to.be.rejectedWith("InvalidFees()");
    });

    it("updatePsmBaseRedemptionFeePercentage should revert when not called by Config contract", async function () {
      await expect(
        moduleCore.write.updatePsmBaseRedemptionFeePercentage(
          [fixture.Id, 500n],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith("OnlyConfigAllowed()");
    });
  });

  describe("expiry", function () {
    it("should return the correct expiry time for a given ID", async function () {
      const currentTime = await time.latest();
      const expiryTime = currentTime + 86400; 
      await corkConfig.write.issueNewDs([
        fixture.Id,
        BigInt(expiryTime),
        parseEther("1"),
        parseEther("5"),
        parseEther("1"),
        10n,
        BigInt(helper.expiry(1000000)),
      ]);
      const expectedExpiry = await moduleCore.read.expiry([fixture.Id]);
      expect(expectedExpiry).to.equal(BigInt(expiryTime));
    });
  });
   
});
