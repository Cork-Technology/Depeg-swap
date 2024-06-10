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
    it("should calculate provided liquidity correctly on the LV (WA:CT = 0.5)", async function () {
      const contract = await loadFixture(deployMathHelper);

      // every ct costs 0.5 wa
      const ratio = parseEther("0.5");
      const amount = parseEther("10");

      const [wa, ct] = await contract.read.calculateAmounts([amount, ratio]);

      console.log("wa: ", formatEther(wa), "ct: ", formatEther(ct));

      // since it costs a half of whatever ct here, it essentially boils down
      // 6666666666666666666 / 2 = 3333333333333333333 + 1 imprecision equal to of ~0,000000000000000001
      const expectedCt = BigInt("6666666666666666666");
      const expectedWa = BigInt("3333333333333333334");

      expect(ct).to.equal(expectedCt);
      expect(wa).to.equal(expectedWa);
    });

    it("should calculate provided liquidity correctly on the LV (WA:CT = 2)", async function () {
      const contract = await loadFixture(deployMathHelper);

      // every 2 wa there must be 1 ct
      const ratio = parseEther("2");
      const amount = parseEther("10");

      const [wa, ct] = await contract.read.calculateAmounts([amount, ratio]);

      // this is just basically a reverse from the above with some imprecision of ~0,000000000000000001
      const expectedWa = BigInt("6666666666666666667");
      const expectedCt = BigInt("3333333333333333333");

      expect(ct).to.equal(expectedCt);
      expect(wa).to.equal(expectedWa);
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

    it("should calculate base lv and ratio correctly(WA:CT = 4) ", async function () {
      const sqrtpricex96 = BigInt("158456325028528675187087900672");
      const expectedRatio = parseEther("4");

      const contract = await loadFixture(deployMathHelper);

      const ratio = await contract.read.calculatePriceRatio([sqrtpricex96, 18]);

      expect(ratio).to.equal(expectedRatio);

      const amount = parseEther("10");

      const [wa, ct] = await contract.read.calculateAmounts([amount, ratio]);

      expect(wa).to.equal(parseEther("8"));
      expect(ct).to.equal(parseEther("2"));
    });

    it("should calculate early lv", async function () {
      const contract = await loadFixture(deployMathHelper);

      const amount = parseEther("1");
      const totalLv = parseEther("10");
      const wa = parseEther("5");

      const result = await contract.read.calculateEarlyLvRate([
        wa,
        totalLv,
        amount,
      ]);

      expect(result).to.equal(parseEther("0.5"));
    });

    it("should calculate precentage fee", async function () {
      const fee = parseEther("10");
      const amount = parseEther("100");

      const contract = await loadFixture(deployMathHelper);

      const result = await contract.read.calculatePrecentageFee([fee, amount]);
      expect(result).to.equal(parseEther("10"));
    });
  });
});
