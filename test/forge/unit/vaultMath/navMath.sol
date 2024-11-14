pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "./../../../../contracts/libraries/MathHelper.sol";
import "./../../Helper.sol";
import "forge-std/console.sol";

contract NavMathTest is Test {
    function test_quote() external {
        uint256 raReserve = 1000 ether;
        uint256 ctReserve = 1050 ether;

        // t = 0.9
        uint256 start = 0 days;
        uint256 end = 10 days;
        uint256 current = 1 days;

        uint256 raQuote = MathHelper.getPriceAsQuote(ctReserve, raReserve, start, end, current);

        vm.assertApproxEqAbs(raQuote, 1.044 ether, 0.001 ether);

        uint256 ctQuote = MathHelper.getPriceAsQuote(raReserve, ctReserve, start, end, current);

        vm.assertApproxEqAbs(ctQuote, 0.957 ether, 0.001 ether);
    }
}
