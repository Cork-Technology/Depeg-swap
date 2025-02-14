pragma solidity ^0.8.24;

import {MathHelper} from "../../../contracts/libraries/MathHelper.sol";

import {KontrolTest} from "./KontrolTest.k.sol";


contract MathHelperTest is KontrolTest {

    uint256 constant UNIT = 1e18;
    uint256 constant ETH_UPPER_BOUND = 2 ** 95;

    function testCalculatePercentageFee(uint256 amount, uint256 ctHeldPercentage) public pure {
        vm.assume(amount > 0);
        vm.assume(ctHeldPercentage >= 0.001 ether);
        vm.assume(ctHeldPercentage <= 100 ether);
        vm.assume(amount < type(uint256).max / ctHeldPercentage);

        uint256 splitted = MathHelper.calculatePercentageFee(ctHeldPercentage, amount);

        vm.assertLe(splitted, amount);
        vm.assertEq(splitted, (amount * ctHeldPercentage) / (100 * UNIT));
    }

    function testCalculateProvideLiquidityAmountBasedOnCtPrice(uint256 amountRa, uint256 priceRatio) public pure {
        vm.assume(priceRatio != 0);
        vm.assume(amountRa < type(uint256).max / UNIT);
        vm.assume(priceRatio < type(uint256).max - UNIT);
        (uint256 ra, uint256 ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amountRa, priceRatio);

        vm.assertLe(ra, amountRa);
        vm.assertLe(ct, amountRa);

        uint256 ctExpected = (amountRa * UNIT) / (priceRatio + UNIT);
        vm.assertEq(ct, ctExpected);
        vm.assertEq(ra, amountRa - ctExpected);
    }

    function testCalculateRedeemLv(MathHelper.RedeemParams calldata params) public pure {
        vm.assume(0 < params.amountLvClaimed);
        // We know this is true when we call the function in redeemLv otherwise the function reverts in burnFrom
        vm.assume(params.amountLvClaimed <= params.totalLvIssued);
        // Overflow check assumptions
        vm.assume(params.amountLvClaimed < type(uint256).max / UNIT);
        vm.assume(params.totalLvIssued < ETH_UPPER_BOUND);
        vm.assume(params.totalVaultLp < ETH_UPPER_BOUND);
        vm.assume(params.totalVaultCt < ETH_UPPER_BOUND);
        vm.assume(params.totalVaultDs < ETH_UPPER_BOUND);
        vm.assume(params.totalVaultPA < ETH_UPPER_BOUND);
        vm.assume(params.totalVaultIdleRa < ETH_UPPER_BOUND);

        MathHelper.RedeemResult memory result = MathHelper.calculateRedeemLv(params);

        vm.assertLe(result.lpLiquidated, params.totalVaultLp);
        vm.assertLe(result.ctReceived, params.totalVaultCt);
        vm.assertLe(result.dsReceived, params.totalVaultDs);

        uint256 proportionalClaim = (params.amountLvClaimed * UNIT) / params.totalLvIssued;
        vm.assertEq(result.ctReceived, (proportionalClaim * params.totalVaultCt) / UNIT);
        vm.assertEq(result.dsReceived, (proportionalClaim * params.totalVaultDs) / UNIT);
        vm.assertEq(result.lpLiquidated, (proportionalClaim * params.totalVaultLp) / UNIT);
    }

    function testCalculateEqualSwapAmount(uint256 amount, uint256 exchangeRates) public pure {
        vm.assume(exchangeRates > 0);
        vm.assume(amount < type(uint256).max / exchangeRates);

        uint256 raDs = MathHelper.calculateEqualSwapAmount(amount, exchangeRates);

        vm.assertEq(raDs, amount * exchangeRates / UNIT);
    }
}