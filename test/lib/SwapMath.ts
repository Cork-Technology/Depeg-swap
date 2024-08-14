import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { formatEther, parseEther } from "viem";
import * as helper from "../helper/TestHelper";

describe("SwapMath", function () {
  async function deploySwapMath() {
    return await hre.viem.deployContract("SwapperMathLibrary");
  }

  it("should deploy the contract", async function () {
    const swapMath = await deploySwapMath();
    expect(swapMath.address).to.be.properAddress;
  });

  it("should calculate DS received correctly", async function () {
    const swapMath = await loadFixture(deploySwapMath);

    //x
    const raReserve = parseEther("1000");
    // y
    const ctReserve = parseEther("900");

    //e
    const raProvided = parseEther("0.1009");

    const [raBorrowed, dsReturned] = await swapMath.read.getAmountOutDs([
      raReserve,
      ctReserve,
      raProvided,
    ]);

    expect(raBorrowed).to.be.closeTo(
      helper.toEthersBigNumer("0.899"),
      helper.toEthersBigNumer("0.001")
    );

    expect(dsReturned).to.be.closeTo(
      helper.toEthersBigNumer("1.00000883"),
      helper.toEthersBigNumer("0.00000001")
    );
  });
});
