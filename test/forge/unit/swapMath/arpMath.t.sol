pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {UD60x18, convert, add, mul, pow, sub, div, unwrap, ud} from "@prb/math/src/UD60x18.sol";
import {SwapperMathLibrary} from "./../../../../contracts/libraries/DsSwapperMathLib.sol";
import "forge-std/console.sol";

contract ArpMath is Test {
    function test_fixedCtPrice() external {
        uint256 arp = 5 ether;

        uint256 ratio = unwrap(SwapperMathLibrary.calcPtConstFixed(ud(arp)));

        vm.assertApproxEqAbs(ratio, 0.95 ether, 0.01 ether);
    }

    function test_effectiveDsPrice() external {
        UD60x18 dsAmount = convert(10e18); // 1 DS tokens
        UD60x18 raProvided = convert(5e18); // 5 RA tokens

        UD60x18 effectiveDsPrice = SwapperMathLibrary.calculateEffectiveDsPrice(dsAmount, raProvided);

        vm.assertEq(0.5 ether, unwrap(effectiveDsPrice));
    }

    function test_calcHiyaAcc() external {
        // t = 1
        uint256 startTime = 1 days;
        uint256 maturityTime = 10 days;
        uint256 currentTime = 1 days;

        uint256 amount = 10 ether;
        uint256 raProvided = 5 ether;
        uint256 decayDiscountInDays = 5 ether;

        uint256 result = SwapperMathLibrary.calcHIYAaccumulated(
            startTime, maturityTime, currentTime, amount, raProvided, decayDiscountInDays
        );

        vm.assertApproxEqAbs(result, 0.1 ether, 0.01 ether);
    }

    function test_calcVhiya() external {
        uint256 startTime = 1 days;
        uint256 maturityTime = 10 days;
        uint256 currentTime = 1 days;

        uint256 amount = 10 ether;
        uint256 decayDiscountInDays = 5 ether;

        uint256 result =
            SwapperMathLibrary.calcVHIYAaccumulated(startTime, maturityTime, currentTime, decayDiscountInDays, amount);

        vm.assertEq(result, 10 ether);
    }

    function test_calcHiya() external {
        // t = 1
        uint256 startTime = 1 days;
        uint256 maturityTime = 10 days;
        uint256 currentTime = 1 days;

        uint256 amount = 10 ether;
        uint256 raProvided = 5 ether;
        uint256 decayDiscountInDays = 5 ether;

        uint256 hiyaAcc = SwapperMathLibrary.calcHIYAaccumulated(
            startTime, maturityTime, currentTime, amount, raProvided, decayDiscountInDays
        );
        uint256 vhiyaAcc =
            SwapperMathLibrary.calcVHIYAaccumulated(startTime, maturityTime, currentTime, decayDiscountInDays, amount);

        uint256 result = SwapperMathLibrary.calculateHIYA(hiyaAcc, vhiyaAcc);

        vm.assertApproxEqAbs(result, 0.01 ether, 0.001 ether);
    }

    function test_calcPt() external {
        UD60x18 dsPrice = ud(0.4 ether);
        UD60x18 pt = SwapperMathLibrary.calcPt(dsPrice);

        vm.assertEq(unwrap(pt), 0.6 ether);
    }

    function test_calcRt() external {
        UD60x18 pt = ud(0.6 ether);
        UD60x18 rt = SwapperMathLibrary.calcRt(pt, convert(1));
        vm.assertApproxEqAbs(0.66 ether, unwrap(rt), 0.01 ether);
    }

    function calcSpotArp() external {
        UD60x18 result = SwapperMathLibrary.calcSpotArp(convert(1), ud(0.4 ether));
        vm.assertApproxEqAbs(0.66 ether, unwrap(result), 0.01 ether);
    }
}
