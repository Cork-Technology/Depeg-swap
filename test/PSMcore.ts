import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseGwei } from "viem";

describe("PSM core", function () {
  async function fixture() {
    return await hre.viem.deployContract("PsmCore");
  }

  describe("deployment", function () {
    it("Should deploy the PsmCore contract", async function () {
      const psmCore = await loadFixture(fixture);
      expect(psmCore).to.be.ok;
    });
  });
});
