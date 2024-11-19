pragma solidity ^0.8.24;

import {SwapperMathLibrary} from "./../../contracts/libraries/DsSwapperMathLib.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./../../contracts/libraries/uni-v2/UniswapV2Library.sol";
import {UD60x18, convert, add, mul, pow, sub, div, unwrap, ud} from "@prb/math/src/UD60x18.sol";

// TODO : adjust tests

contract SwapMathTest is Test {
    function test_calculateDecay() external {
        // 1 %
        UD60x18 decayDiscountInDays = convert(1);

        // together make 1 day worth of discount
        UD60x18 issuanceTime = convert(2 days);
        UD60x18 currentTime = convert(3 days);

        UD60x18 discount = SwapperMathLibrary.calculateDecayDiscount(decayDiscountInDays, issuanceTime, currentTime);

        vm.assertApproxEqAbs(unwrap(discount), 99e18, 0.0000001 ether);
    }

    function test_calculateRolloverSale() external {
        uint256 lvReserve = 100 ether;
        uint256 psmReserve = 100 ether;
        uint256 raProvided = 1 ether;
        uint256 hiya = 11.11111111 ether;

        (
            uint256 lvProfit,
            uint256 psmProfit,
            uint256 raLeft,
            uint256 dsReceived,
            uint256 lvReserveUsed,
            uint256 psmReserveUsed
        ) = SwapperMathLibrary.calculateRolloverSale(lvReserve, psmReserve, raProvided, hiya);

        vm.assertApproxEqAbs(lvProfit, 0.5 ether, 0.0001 ether);
        vm.assertApproxEqAbs(psmProfit, 0.5 ether, 0.0001 ether);
        vm.assertApproxEqAbs(raLeft, 0 ether, 0.0001 ether);
        vm.assertApproxEqAbs(dsReceived, 10 ether, 0.0001 ether);
        vm.assertApproxEqAbs(lvReserveUsed, 5 ether, 0.0001 ether);
        vm.assertApproxEqAbs(psmReserveUsed, 5 ether, 0.0001 ether);

        // 25% profit for lv
        lvReserve = 50 ether;
        // 75% profit for psm
        psmReserve = 150 ether;

        (lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed) =
            SwapperMathLibrary.calculateRolloverSale(lvReserve, psmReserve, raProvided, hiya);

        vm.assertApproxEqAbs(lvProfit, 0.25 ether, 0.0001 ether);
        vm.assertApproxEqAbs(psmProfit, 0.75 ether, 0.0001 ether);
        vm.assertApproxEqAbs(raLeft, 0 ether, 0.0001 ether);
        vm.assertApproxEqAbs(dsReceived, 10 ether, 0.0001 ether);
        vm.assertApproxEqAbs(lvReserveUsed, 2.5 ether, 0.0001 ether);
        vm.assertApproxEqAbs(psmReserveUsed, 7.5 ether, 0.0001 ether);
    }

    function test_sellDs() external {
        uint256 ctReserve = 1000 ether;
        uint256 raReserve = 900 ether;

        uint256 amountToSell = 5 ether;

        uint256 borrwedAmount = 4.527164981 ether;

        (bool success, uint256 raReceived) = SwapperMathLibrary.getAmountOutSellDs(borrwedAmount, amountToSell);

        vm.assertEq(success, true);
        vm.assertApproxEqAbs(raReceived, 0.472835019 ether, 0.000001 ether);

        // can't sell if  CT > RA
        amountToSell = 4 ether;
        (success, raReceived) = SwapperMathLibrary.getAmountOutSellDs(borrwedAmount, amountToSell);

        vm.assertEq(success, false);
    }

    function testFuzz_sellDs(uint256 amountToSell, uint256 repaymentAmount) external {
        vm.assume(amountToSell > repaymentAmount);

        (bool success, uint256 raReceived) = SwapperMathLibrary.getAmountOutSellDs(repaymentAmount, amountToSell);

        vm.assertTrue(success);
    }
}
