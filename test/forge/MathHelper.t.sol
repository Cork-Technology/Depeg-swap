pragma solidity ^0.8.0;

import "./../../contracts/libraries/MathHelper.sol";
import "./Helper.sol";

contract MathHelperTest is Helper {
    function testFuzz_shouldCalculateProvideLiquidityAmountCorrectly11(uint256 amountRa) external {
        // no more than 10 thousand TRILLION * 10^18
        vm.assume(amountRa < 10000000000000000 ether);

        uint256 priceRatio = 1 ether;
        uint256 exchangeRate = 1 ether;

        (uint256 ra, uint256 ct) =
            MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amountRa, priceRatio);

        vm.assertApproxEqAbs(ra, amountRa / 2, 1);
        vm.assertApproxEqAbs(ct, amountRa / 2, 1);
    }


    function test_DsRedeemAmount() external {
        uint256 rates = 1.1 ether;
        uint256 pa = 5 ether;

        uint256 amount = MathHelper.calculateEqualSwapAmount(pa, rates);

        vm.assertEq(amount, 5.5 ether);
    }

    function testFuzz_DsRedeemAmount(uint256 pa, uint256 rates) external {
        pa = bound(pa, 0.1 ether, 10 ether);
        rates = bound(rates, 1 ether, 1.5 ether);

        uint256 amount = MathHelper.calculateEqualSwapAmount(pa, rates);

        vm.assertEq(amount, pa * rates / 1e18);
    }
}
