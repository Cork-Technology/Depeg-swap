import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import * as helper from "../helper/TestHelper";

describe("CorkConfig", function () {
  let {
    defaultSigner,
    secondSigner,
    signers,
  }: ReturnType<typeof helper.getSigners> = {} as any;

  let corkConfig: Awaited<ReturnType<typeof helper.deployCorkConfig>>;

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, signers } = helper.getSigners(__signers));
    secondSigner = signers[1];
  });

  beforeEach(async () => {
    corkConfig = await loadFixture(helper.deployCorkConfig);
  });

  it("should deploy correctly", async function () {
    const __corkConfig = await hre.viem.deployContract("CorkConfig", [], {
      client: {
        wallet: defaultSigner,
      },
    });
    expect(__corkConfig).to.be.ok;
    expect(
      await __corkConfig.read.hasRole([
        await __corkConfig.read.DEFAULT_ADMIN_ROLE(),
        defaultSigner.account.address,
      ])
    ).to.be.equals(true);
    expect(
      await __corkConfig.read.hasRole([
        await __corkConfig.read.MANAGER_ROLE(),
        defaultSigner.account.address,
      ])
    ).to.be.equals(false);
    expect(await __corkConfig.read.paused()).to.be.equals(false);
  });

  describe("SetModuleCore", function () {
    it("setModuleCore should work correctly", async function () {
      expect(await corkConfig.contract.read.moduleCore()).to.not.be.equals(
        defaultSigner.account.address
      );
      expect(
        await corkConfig.contract.write.setModuleCore(
          [secondSigner.account.address],
          {
            account: defaultSigner.account,
          }
        )
      ).to.be.ok;
      expect(
        await corkConfig.contract.read
          .moduleCore()
          .then((result) => result.toLocaleLowerCase())
      ).to.be.equals(secondSigner.account.address);
    });

    it("Revert when non MANAGER call setModuleCore", async function () {
      await expect(
        corkConfig.contract.write.setModuleCore(
          [defaultSigner.account.address],
          {
            account: secondSigner.account,
          }
        )
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("Pause", function () {
    it("pause should work correctly", async function () {
      expect(await corkConfig.contract.read.paused()).to.be.equals(false);

      await expect(
        await corkConfig.contract.write.pause({
          account: defaultSigner.account,
        })
      ).to.be.ok;

      expect(await corkConfig.contract.read.paused()).to.be.equals(true);
    });

    it("Revert when non MANAGER call pause", async function () {
      await expect(
        corkConfig.contract.write.pause({
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });

  describe("Unpause", function () {
    it("unpause should work correctly", async function () {
      await corkConfig.contract.write.pause();

      expect(await corkConfig.contract.read.paused()).to.be.equals(true);

      await expect(
        await corkConfig.contract.write.unpause({
          account: defaultSigner.account,
        })
      ).to.be.ok;

      expect(await corkConfig.contract.read.paused()).to.be.equals(false);
    });

    it("Revert when non MANAGER call pause", async function () {
      await expect(
        corkConfig.contract.write.unpause({
          account: secondSigner.account,
        })
      ).to.be.rejectedWith("CallerNotManager()");
    });
  });
});
