import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import * as helper from "../helper/TestHelper";

describe("CorkConfig", function () {
  var primarySigner: any;
  var secondSigner: any;

  var corkConfigContract: any;

  before(async () => {
    const { defaultSigner, signers } = await helper.getSigners();
    primarySigner = defaultSigner;
    secondSigner = signers[1];
  });

  beforeEach(async () => {
    const corkConfig = await loadFixture(
      helper.deployCorkConfig
    );
    corkConfigContract = await hre.viem.getContractAt(
      "CorkConfig",
      corkConfig.contract.address
    );
  });

  it("should deploy correctly", async function () {
    corkConfigContract = await hre.viem.deployContract("CorkConfig", [],
      {
        client: {
          wallet: primarySigner,
        }
      }
    );
    expect(corkConfigContract).to.be.ok;
    expect(await corkConfigContract.read.hasRole([await corkConfigContract.read.DEFAULT_ADMIN_ROLE(),
    primarySigner.account.address]
    )).to.be.equals(true);
    expect(await corkConfigContract.read.hasRole([await corkConfigContract.read.MANAGER_ROLE(),
    primarySigner.account.address]
    )).to.be.equals(false);
    expect(await corkConfigContract.read.paused()).to.be.equals(false);
  });

  describe("SetModuleCore", function () {
    it("setModuleCore should work correctly", async function () {
      expect(await corkConfigContract.read.moduleCore()).to.not.be.equals(primarySigner.account.address);
      await expect(await corkConfigContract.write.setModuleCore([secondSigner.account.address], {
        account: primarySigner.account,
      })).to.be.ok;
      expect(await (await corkConfigContract.read.moduleCore()).toLowerCase()).to.be.equals(secondSigner.account.address);
    })

    it("Revert when non MANAGER call setModuleCore", async function () {
      await expect(corkConfigContract.write.setModuleCore([primarySigner.account.address], {
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  });

  describe("Pause", function () {
    it("pause should work correctly", async function () {
      expect(await corkConfigContract.read.paused()).to.be.equals(false);

      await expect(await corkConfigContract.write.pause({
        account: primarySigner.account,
      })).to.be.ok;

      expect(await corkConfigContract.read.paused()).to.be.equals(true);
    })

    it("Revert when non MANAGER call pause", async function () {
      await expect(corkConfigContract.write.pause({
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  })

  describe("Unpause", function () {
    it("unpause should work correctly", async function () {
      await corkConfigContract.write.pause();

      expect(await corkConfigContract.read.paused()).to.be.equals(true);

      await expect(await corkConfigContract.write.unpause({
        account: primarySigner.account,
      })).to.be.ok;

      expect(await corkConfigContract.read.paused()).to.be.equals(false);
    })

    it("Revert when non MANAGER call pause", async function () {
      await expect(corkConfigContract.write.unpause({
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  })
});
