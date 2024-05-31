// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// TODO: add tests
library MathHelper {
    function calculateAmounts(
        uint256 amount,
        uint256 priceRatio
    )
        internal
        pure
        returns (
            uint256 amountWa,
            uint256 amountCt,
            uint256 leftoverWa,
            uint256 leftoverCt
        )
    {
        uint256 requiredWa = (amount * 1e18) / priceRatio;
        uint256 requiredCt = (amount * priceRatio) / 1e18;

        if (requiredCt <= amount) {
            amountWa = amount;
            amountCt = requiredCt;
            leftoverWa = 0;
            leftoverCt = amount - requiredCt;
        } else {
            amountWa = requiredWa;
            amountCt = amount;
            leftoverWa = amount - requiredWa;
            leftoverCt = 0;
        }
    }

    function calculatePriceRatio(
        uint160 sqrtPriceX96
    ) internal pure returns (uint256) {
        return (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (1 << 192);
    }
}
