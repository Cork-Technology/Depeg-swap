import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import * as helper from "../helper/TestHelper";

describe("CorkConfig", function () {
  let primarySigner: any;
  let secondSigner: any;

  let corkConfig: any;

  before(async () => {
    const { defaultSigner, signers } = await helper.getSigners();
    primarySigner = defaultSigner;
    secondSigner = signers[1];
  });

  beforeEach(async () => {
    const corkConfigInstance = await loadFixture(
      helper.deployCorkConfig
    );
    corkConfig = await hre.viem.getContractAt(
      "CorkConfig",
      corkConfigInstance.contract.address
    );
  });

  it("should deploy correctly", async function () {
    corkConfig = await hre.viem.deployContract("CorkConfig", [],
      {
        client: {
          wallet: primarySigner,
        }
      }
    );
    expect(corkConfig).to.be.ok;
    expect(await corkConfig.read.hasRole([await corkConfig.read.DEFAULT_ADMIN_ROLE(),
    primarySigner.account.address]
    )).to.be.equals(true);
    expect(await corkConfig.read.hasRole([await corkConfig.read.MANAGER_ROLE(),
    primarySigner.account.address]
    )).to.be.equals(false);
    expect(await corkConfig.read.paused()).to.be.equals(false);
  });

  describe("SetModuleCore", function () {
    it("setModuleCore should work correctly", async function () {
      expect(await corkConfig.read.moduleCore()).to.not.be.equals(primarySigner.account.address);
      await expect(await corkConfig.write.setModuleCore([secondSigner.account.address], {
        account: primarySigner.account,
      })).to.be.ok;
      expect(await (await corkConfig.read.moduleCore()).toLowerCase()).to.be.equals(secondSigner.account.address);
    })

    it("Revert when non MANAGER call setModuleCore", async function () {
      await expect(corkConfig.write.setModuleCore([primarySigner.account.address], {
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  });

  describe("Pause", function () {
    it("pause should work correctly", async function () {
      expect(await corkConfig.read.paused()).to.be.equals(false);

      await expect(await corkConfig.write.pause({
        account: primarySigner.account,
      })).to.be.ok;

      expect(await corkConfig.read.paused()).to.be.equals(true);
    })

    it("Revert when non MANAGER call pause", async function () {
      await expect(corkConfig.write.pause({
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  })

  describe("Unpause", function () {
    it("unpause should work correctly", async function () {
      await corkConfig.write.pause();

      expect(await corkConfig.read.paused()).to.be.equals(true);

      await expect(await corkConfig.write.unpause({
        account: primarySigner.account,
      })).to.be.ok;

      expect(await corkConfig.read.paused()).to.be.equals(false);
    })

    it("Revert when non MANAGER call pause", async function () {
      await expect(corkConfig.write.unpause({
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  })
});
