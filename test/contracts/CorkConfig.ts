import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import * as helper from "../helper/TestHelper";

describe("CorkConfig", function () {
  it("should deploy correctly", async function () {
    const { defaultSigner } = await helper.getSigners();

    const contract = await hre.viem.deployContract("CorkConfig", [],
      {
        client: {
          wallet: defaultSigner,
        }
      }
    );

    expect(contract).to.be.ok;
    expect(await contract.read.hasRole([await contract.read.DEFAULT_ADMIN_ROLE(),
    defaultSigner.account.address]
    )).to.be.equals(true);
    expect(await contract.read.hasRole([await contract.read.MANAGER_ROLE(),
    defaultSigner.account.address]
    )).to.be.equals(false);
    expect(await contract.read.paused()).to.be.equals(false);
  });

  describe("SetModuleCore", function () {
    it("setModuleCore should work correctly", async function () {
      const { defaultSigner, signers } = await helper.getSigners();
      const secondSigner = signers[1];
      const corkConfig = await loadFixture(
        helper.deployCorkConfig
      );

      const configContract = await hre.viem.getContractAt(
        "CorkConfig",
        corkConfig.contract.address
      );
      expect(await configContract.read.moduleCore()).to.not.be.equals(defaultSigner.account.address);
      await expect(await configContract.write.setModuleCore([secondSigner.account.address], {
        account: defaultSigner.account,
      })).to.be.ok;
      expect(await (await configContract.read.moduleCore()).toLowerCase()).to.be.equals(secondSigner.account.address);
    })

    it("Revert when non MANAGER call setModuleCore", async function () {
      const { defaultSigner, signers } = await helper.getSigners();
      const secondSigner = signers[1];
      const corkConfig = await loadFixture(
        helper.deployCorkConfig
      );

      const configContract = await hre.viem.getContractAt(
        "CorkConfig",
        corkConfig.contract.address
      );
      await expect(configContract.write.setModuleCore([defaultSigner.account.address], {
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  });

  describe("Pause", function () {
    it("pause should work correctly", async function () {
      const { defaultSigner } = await helper.getSigners();
      const corkConfig = await loadFixture(
        helper.deployCorkConfig
      );

      const configContract = await hre.viem.getContractAt(
        "CorkConfig",
        corkConfig.contract.address
      );
      expect(await configContract.read.paused()).to.be.equals(false);

      await expect(await configContract.write.pause({
        account: defaultSigner.account,
      })).to.be.ok;

      expect(await configContract.read.paused()).to.be.equals(true);
    })

    it("Revert when non MANAGER call pause", async function () {
      const { defaultSigner, signers } = await helper.getSigners();
      const secondSigner = signers[1];
      const corkConfig = await loadFixture(
        helper.deployCorkConfig
      );

      const configContract = await hre.viem.getContractAt(
        "CorkConfig",
        corkConfig.contract.address
      );
      await expect(configContract.write.pause({
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  })

  describe("Unpause", function () {
    it("unpause should work correctly", async function () {
      const { defaultSigner } = await helper.getSigners();
      const corkConfig = await loadFixture(
        helper.deployCorkConfig
      );

      const configContract = await hre.viem.getContractAt(
        "CorkConfig",
        corkConfig.contract.address
      );
      await configContract.write.pause();

      expect(await configContract.read.paused()).to.be.equals(true);

      await expect(await configContract.write.unpause({
        account: defaultSigner.account,
      })).to.be.ok;

      expect(await configContract.read.paused()).to.be.equals(false);
    })

    it("Revert when non MANAGER call pause", async function () {
      const { defaultSigner, signers } = await helper.getSigners();
      const secondSigner = signers[1];
      const corkConfig = await loadFixture(
        helper.deployCorkConfig
      );

      const configContract = await hre.viem.getContractAt(
        "CorkConfig",
        corkConfig.contract.address
      );
      await expect(configContract.write.unpause({
        account: secondSigner.account,
      })).to.be.rejectedWith('CallerNotManager()');
    })
  })
});
