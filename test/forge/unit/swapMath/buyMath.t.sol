pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SD59x18, convert, sd, add, mul, pow, sub, div, abs, unwrap} from "@prb/math/src/SD59x18.sol";
import "./../../../../contracts/libraries/DsSwapperMathLib.sol";
import "forge-std/console.sol";

contract BuyMathTest is Test {
    int256 internal constant START = 0 days;
    int256 internal constant END = 100 days;

    function test_t() external {
        SD59x18 current = convert(10 days);
        SD59x18 t = BuyMathBisectionSolver.computeT(convert(START), convert(END), current);

        int256 tUnwrapped = unwrap(t);
        vm.assertEq(tUnwrapped, 0.9e18);
    }

    function test_1minT() external {
        SD59x18 current = convert(10 days);
        SD59x18 t = BuyMathBisectionSolver.computeOneMinusT(convert(START), convert(END), current);

        int256 tUnwrapped = unwrap(t);
        vm.assertEq(tUnwrapped, 0.1e18);
    }

    function test_buyMath() external {
        SD59x18 x = convert(1000 ether);
        SD59x18 y = convert(1050 ether);
        SD59x18 e = convert(0.5 ether);

        SD59x18 _1MinusT = sd(0.01 ether);

        uint256 result = uint256(convert(BuyMathBisectionSolver.findRoot(x, y, e, _1MinusT)));

        vm.assertApproxEqAbs(result, 9.054 ether, 0.001 ether);
    }
}
