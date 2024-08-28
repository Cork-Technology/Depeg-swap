import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { formatEther, parseEther } from "viem";
import * as helper from "../helper/TestHelper";

describe("Math Helper", function () {
  async function deployMathHelper() {
    return await hre.viem.deployContract("MathHelper", []);
  }
  describe("LV math", function () {
    it("should calculate provided liquidity correctly on the LV (WA:CT = 0.5)", async function () {
      const contract = await loadFixture(deployMathHelper);

      // ct price
      const ratio = parseEther("0.5");
      const amount = parseEther("10");

      const [wa, ct] =
        await contract.read.calculateProvideLiquidityAmountBasedOnCtPrice([
          amount,
          ratio,
        ]);


      // since it costs a half of whatever ct here, it essentially boils down
      // 6666666666666666666 / 2 = 3333333333333333333 + 1
      const expectedCt = BigInt("6666666666666666666");
      const expectedWa = BigInt("3333333333333333334");

      expect(ct).to.equal(expectedCt);
      expect(wa).to.equal(expectedWa);
    });

    it("should calculate provided liquidity correctly on the LV (WA:CT = 2)", async function () {
      const contract = await loadFixture(deployMathHelper);

      // ct price
      const ratio = parseEther("2");
      const amount = parseEther("10");

      const [wa, ct] =
        await contract.read.calculateProvideLiquidityAmountBasedOnCtPrice([
          amount,
          ratio,
        ]);

      // this is just basically a reverse from the above with some imprecision of ~0,000000000000000001
      const expectedWa = BigInt("6666666666666666667");
      const expectedCt = BigInt("3333333333333333333");

      expect(wa).to.equal(expectedWa);
      expect(ct).to.equal(expectedCt);
    });

    it("should convert sqrtx96 to ratio (4)", async function () {
      const sqrtpricex96 = BigInt("158456325028528675187087900672");
      const ratio = parseEther("4");

      const contract = await loadFixture(deployMathHelper);

      const converted = await contract.read.calculatePriceRatioUniV4([
        sqrtpricex96,
        18,
      ]);

      expect(converted).to.equal(ratio);
    });

    it("should calculate ra and pa value per lv", async function () {
      const contract = await loadFixture(deployMathHelper);

      const totalLv = parseEther("10");
      const accruedRa = parseEther("1");
      const accruedPa = parseEther("1");
      const amount = parseEther("2");

      const [raPerLv, paPerLv] = await contract.read.calculateBaseWithdrawal([
        totalLv,
        accruedRa,
        accruedPa,
        amount,
      ]);

      const claimedAmount = parseEther("0.2");

      expect(raPerLv).to.equal(claimedAmount);
      expect(paPerLv).to.equal(claimedAmount);
    });

    it("should calculate base lv and ratio correctly(WA:CT = 4) ", async function () {
      const sqrtpricex96 = BigInt("158456325028528675187087900672");
      const expectedRatio = parseEther("4");

      const contract = await loadFixture(deployMathHelper);

      const ratio = await contract.read.calculatePriceRatioUniV4([
        sqrtpricex96,
        18,
      ]);

      expect(ratio).to.equal(expectedRatio);

      const amount = parseEther("10");

      const [wa, ct] =
        await contract.read.calculateProvideLiquidityAmountBasedOnCtPrice([
          amount,
          ratio,
        ]);

      expect(ct).to.equal(parseEther("2"));
      expect(wa).to.equal(parseEther("8"));
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

    it("should correctly calcuate liquidity separation", async function () {
      const contract = await loadFixture(deployMathHelper);

      const totalLvIssued = parseEther("10");
      const totalLvWithdrawn = parseEther("3");
      const ra = parseEther("1");

      const [withdraw, amm, _] = await contract.read.separateLiquidity([
        ra,
        totalLvIssued,
        totalLvWithdrawn,
      ]);

      expect(withdraw).to.equal(parseEther("0.3"));
      expect(amm).to.equal(parseEther("0.7"));
    });

    it("should calculate Uniswap v2 LP value correctly(simple round math)", async function () {
      const contract = await loadFixture(deployMathHelper);

      const totalLpSupply = parseEther("10");
      const raReserve = parseEther("10");
      const ctReserve = parseEther("10");

      const [ra, ct] = await contract.read.calculateUniV2LpValue([
        totalLpSupply,
        raReserve,
        ctReserve,
      ]);

      expect(ra).to.equal(parseEther("1"));
      expect(ct).to.equal(parseEther("1"));
    });

    it("should calculate Uniswap v2 LP value correctly(float math)", async function () {
      const contract = await loadFixture(deployMathHelper);

      const totalLpSupply = parseEther("10");
      const raReserve = parseEther("0.5");
      const ctReserve = parseEther("0.2");

      const [ra, ct] = await contract.read.calculateUniV2LpValue([
        totalLpSupply,
        raReserve,
        ctReserve,
      ]);

      expect(ra).to.equal(parseEther("0.05"));
      expect(ct).to.equal(parseEther("0.02"));
    });

    it("should calculate LV token value relative to uni v2 LP(simple round math)", async function () {
      const contract = await loadFixture(deployMathHelper);

      const totalLpSupply = parseEther("100");
      const totalLpOwned = parseEther("10");
      const raReserve = parseEther("10");
      const ctReserve = parseEther("10");
      const lvSupply = parseEther("10");

      const [raValuePerLv, ctValuePerLV] =
        await contract.read.calculateLvValueFromUniV2Lp([
          totalLpSupply,
          totalLpOwned,
          raReserve,
          ctReserve,
          lvSupply,
        ]);

      expect(raValuePerLv).to.equal(parseEther("0.1"));
      expect(ctValuePerLV).to.equal(parseEther("0.1"));
    });

    it("should calculate LV token value relative to uni v2 LP(float math)", async function () {
      const contract = await loadFixture(deployMathHelper);

      const totalLpSupply = parseEther("100");
      const totalLpOwned = parseEther("5");
      const raReserve = parseEther("0.8");
      const ctReserve = parseEther("0.8");
      const lvSupply = parseEther("100");

      const [raValuePerLv, ctValuePerLV] =
        await contract.read.calculateLvValueFromUniV2Lp([
          totalLpSupply,
          totalLpOwned,
          raReserve,
          ctReserve,
          lvSupply,
        ]);

      expect(raValuePerLv).to.equal(parseEther("0.0004"));
      expect(ctValuePerLV).to.equal(parseEther("0.0004"));
    });
  });

  describe("PSM Math", function () {
    it("should calcuate psm deposit amount with exchange rates", async function () {
      const contract = await loadFixture(deployMathHelper);

      const amount = parseEther("10");
      const rate = parseEther("1");

      const result = await contract.read.calculateDepositAmountWithExchangeRate(
        [amount, rate]
      );

      expect(result).to.equal(parseEther("10"));

      const rate2 = parseEther("2");

      const result2 =
        await contract.read.calculateDepositAmountWithExchangeRate([
          amount,
          rate2,
        ]);

      expect(result2).to.equal(parseEther("5"));

      const rate3 = parseEther("0.5");

      const result3 =
        await contract.read.calculateDepositAmountWithExchangeRate([
          amount,
          rate3,
        ]);

      expect(result3).to.equal(parseEther("20"));

      const result6 =
        await contract.read.calculateDepositAmountWithExchangeRate([
          parseEther("0.5"),
          rate3,
        ]);

      expect(result6).to.equal(parseEther("1"));
    });

    it("should calculate psm redeem amount with exchange rates", async function () {
      const contract = await loadFixture(deployMathHelper);

      const amount = parseEther("10");
      const rate = parseEther("1");

      const result = await contract.read.calculateRedeemAmountWithExchangeRate([
        amount,
        rate,
      ]);

      expect(result).to.equal(parseEther("10"));

      const rate2 = parseEther("2");

      const result2 = await contract.read.calculateRedeemAmountWithExchangeRate(
        [amount, rate2]
      );

      expect(result2).to.equal(parseEther("20"));

      const rate3 = parseEther("0.5");

      const result3 = await contract.read.calculateRedeemAmountWithExchangeRate(
        [amount, rate3]
      );

      expect(result3).to.equal(parseEther("5"));
    });

    it("should balance when psm deposit and redeem using exchange rate", async function () {
      const contract = await loadFixture(deployMathHelper);

      const amount = parseEther("10");
      const rate = parseEther("1");

      const deposit =
        await contract.read.calculateDepositAmountWithExchangeRate([
          amount,
          rate,
        ]);

      const redeem = await contract.read.calculateRedeemAmountWithExchangeRate([
        deposit,
        rate,
      ]);

      expect(redeem).to.equal(amount);

      const rate2 = parseEther("2");

      const deposit2 =
        await contract.read.calculateDepositAmountWithExchangeRate([
          amount,
          rate2,
        ]);

      const redeem2 = await contract.read.calculateRedeemAmountWithExchangeRate(
        [deposit2, rate2]
      );

      expect(redeem2).to.equal(amount);

      const rate3 = parseEther("0.5");


      const deposit3 =
        await contract.read.calculateDepositAmountWithExchangeRate([
          amount,
          rate3,
        ]);

      const redeem3 = await contract.read.calculateRedeemAmountWithExchangeRate(
        [deposit3, rate3]
      );

      expect(redeem3).to.equal(amount);
    });
  });
});
