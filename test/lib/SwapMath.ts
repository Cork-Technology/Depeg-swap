import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { formatEther, parseEther } from "viem";
import * as helper from "../helper/TestHelper";

const DAY_IN_SECS = 86400n;

describe("SwapMath", function () {
  async function deploySwapMath() {
    return await hre.viem.deployContract("SwapperMathLibrary");
  }
  let swapMath: Awaited<ReturnType<typeof deploySwapMath>>;

  before(async function () {
    swapMath = await loadFixture(deploySwapMath);
  });

  it("should deploy the contract", async function () {
    expect(swapMath.address).to.be.properAddress;
  });

  it("should calculate DS received correctly", async function () {
    // y
    const ctReserve = parseEther("100000000");
    //x
    const raReserve = parseEther("90000000");

    //e
    const raProvided = parseEther("1");

    const [raBorrowed, dsReturned] = await swapMath.read.getAmountOutBuyDs([
      parseEther("1"),
      raReserve,
      ctReserve,
      raProvided,
    ]);

    expect(raBorrowed).to.be.closeTo(
      helper.toEthersBigNumer("9"),
      helper.toEthersBigNumer("0.1")
    );

    expect(dsReturned).to.be.closeTo(
      helper.toEthersBigNumer("9.99"),
      helper.toEthersBigNumer("0.01")
    );
  });

  it("should calculate discount", async function () {
    const issuanceTimestamp = DAY_IN_SECS * 1n;
    // 28 days after issuance
    const currenTime = DAY_IN_SECS * 29n;
    // 2 % per day
    const decayDiscountInDays = parseEther("2");

    const result = await swapMath.read.calculateDecayDiscount([
      decayDiscountInDays,
      issuanceTimestamp,
      currenTime,
    ]);

    expect(result).to.be.closeTo(
      helper.toEthersBigNumer("44"),
      // precision up to 11 decimals
      helper.toEthersBigNumer("0.000000000001")
    );
  });

  it("should calculate cumulated HPA", async function () {
    const issuanceTimestamp = DAY_IN_SECS * 1n;
    // 28 days after issuance
    const currenTime = DAY_IN_SECS * 29n;
    // 2 % per day
    const decayDiscountInDays = parseEther("2");

    const result = await swapMath.read.calculateHPAcumulated([
      parseEther("0.1"),
      parseEther("100"),
      decayDiscountInDays,
      issuanceTimestamp,
      currenTime,
    ]);

    expect(result).to.be.closeTo(
      helper.toEthersBigNumer("4.4"),
      // precision up to 11 decimals
      helper.toEthersBigNumer("0.000000000001")
    );
  });

  it("should calculate cumulated VHPA", async function () {
    const issuanceTimestamp = DAY_IN_SECS * 1n;
    // 28 days after issuance
    const currenTime = DAY_IN_SECS * 29n;
    // 2 % per day
    const decayDiscountInDays = parseEther("2");

    const result = await swapMath.read.calculateVHPAcumulated([
      parseEther("100"),
      decayDiscountInDays,
      issuanceTimestamp,
      currenTime,
    ]);

    expect(result).to.be.closeTo(
      helper.toEthersBigNumer("44"),
      // precision up to 11 decimals
      helper.toEthersBigNumer("0.000000000001")
    );
  });

  it("should calculate HPA", async function () {
    let result = await swapMath.read.calculateHPA([
      parseEther("4.4"),
      parseEther("44"),
    ]);

    expect(result).to.be.closeTo(
      helper.toEthersBigNumer("0.1"),
      // precision up to 11 decimals
      helper.toEthersBigNumer("0.000000000001")
    );
  });

  it("should calculate effective DS price", async function () {
    const raProvided = parseEther("0.1");
    const dsReturned = parseEther("10000");
    const result = await swapMath.read.calculateEffectiveDsPrice([
      dsReturned,
      raProvided,
    ]);

    expect(result).to.be.equal(parseEther("0.00001"));
  });
});
