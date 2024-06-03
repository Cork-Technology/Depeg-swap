import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { formatEther, parseEther } from "viem";

describe("Math Helper", function () {
  async function deployMathHelper() {
    return await hre.viem.deployContract("MathHelper", []);
  }
  describe("LV math", function () {
    it("should calculate provided liquidity correctly on the LV (WA:CT = 0.2)", async function () {
      const contract = await loadFixture(deployMathHelper);

      // every 5 ct there must be 1 wa
      const ratio = parseEther("0.2");
      const amount = parseEther("10");

      const [wa, ct, leftoverWa, leftoverCt] =
        await contract.read.calculateAmounts([amount, ratio]);

      console.log(
        "wa: ",
        formatEther(wa),
        "ct: ",
        formatEther(ct),
        "leftover wa: ",
        formatEther(leftoverWa),
        "leftover ct: ",
        formatEther(leftoverCt)
      );

      expect(wa).to.equal(parseEther("2"));
      expect(ct).to.equal(parseEther("10"));
      expect(leftoverWa).to.equal(parseEther("8"));
      expect(leftoverCt).to.equal(parseEther("0"));
    });

    it("should calculate provided liquidity correctly on the LV (WA:CT = 2)", async function () {
      const contract = await loadFixture(deployMathHelper);

      // every 2 wa there must be 1 ct
      const ratio = parseEther("2");
      const amount = parseEther("10");

      const [wa, ct, leftoverWa, leftoverCt] =
        await contract.read.calculateAmounts([amount, ratio]);

      console.log(
        "wa: ",
        formatEther(wa),
        "ct: ",
        formatEther(ct),
        "leftover wa: ",
        formatEther(leftoverWa),
        "leftover ct: ",
        formatEther(leftoverCt)
      );

      expect(wa).to.equal(parseEther("10"));
      expect(ct).to.equal(parseEther("5"));
      expect(leftoverWa).to.equal(parseEther("0"));
      expect(leftoverCt).to.equal(parseEther("5"));
    });

    it("should convert sqrtx96 to ratio (4)", async function () {
      const sqrtpricex96 = BigInt("158456325028528675187087900672");
      const ratio = parseEther("4");

      const contract = await loadFixture(deployMathHelper);

      const converted = await contract.read.calculatePriceRatio([
        sqrtpricex96,
        18,
      ]);

      expect(converted).to.equal(ratio);
    });

    it("should calculate ra and pa value per lv", async function () {
      const contract = await loadFixture(deployMathHelper);

      const totalLv = parseEther("10");
      const accruedRa = parseEther("10");
      const accruedPa = parseEther("10");
      const amount = parseEther("2");

      const [raPerLv, paPerLv] = await contract.read.calculateBaseWithdrawal([
        totalLv,
        accruedRa,
        accruedPa,
        amount,
      ]);

      const claimedAmount = parseEther("2");

      expect(raPerLv).to.equal(claimedAmount);
      expect(paPerLv).to.equal(claimedAmount);
    });
  });
});
