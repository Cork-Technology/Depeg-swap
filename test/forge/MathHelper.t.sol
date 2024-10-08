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
            MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amountRa, priceRatio, exchangeRate);

        vm.assertApproxEqAbs(ra, amountRa / 2, 1);
        vm.assertApproxEqAbs(ct, amountRa / 2, 1);
    }

    function testFuzz_ProvideLiquidityNot11(uint256 priceRatio, uint256 exchangeRate) external {
        priceRatio =  bound(priceRatio, 0.0001 ether, 10 ether);
        exchangeRate = bound(exchangeRate, 1 ether, 10 ether);

        uint256 amountRa = 1 ether;

        (uint256 ra, uint256 ct) =
            MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amountRa, priceRatio, exchangeRate);

        uint256 amountToDepositAsCt = amountRa - ra;
        vm.assertApproxEqAbs(amountToDepositAsCt * 1e18 / exchangeRate, ct, 1);
    }
}
