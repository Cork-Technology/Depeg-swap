// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// TODO: add tests
library MathHelper {
    /// @dev default decimals for now to calculate price ratio
    uint8 internal constant DEFAULT_DECIMAL = 18;

    function calculateAmounts(
        uint256 amount,
        uint256 priceRatio
    )
        external
        pure
        returns (
            uint256 amountWa,
            uint256 amountCt,
            uint256 leftoverWa,
            uint256 leftoverCt
        )
    {
        uint256 requiredWa = (amount * priceRatio) / 1e18;
        uint256 requiredCt = (amount * 1e18) / priceRatio;

        if (requiredWa <= amount) {
            amountCt = amount;
            amountWa = requiredWa;
            leftoverCt = 0;
            leftoverWa = amount - requiredWa;
        } else {
            amountCt = requiredCt;
            amountWa = amount;
            leftoverCt = amount - requiredCt;
            leftoverWa = 0;
        }
    }

    // TODO: test this, and maybe add support for 2 different decimals token? but since we're
    // using wa and ct, which both has 18 decimals so will default into that one for now
    /// @dev should only pass ERC20.decimals() onto the decimal field
    /// @dev will output price ratio in 18 decimal precision.
    function calculatePriceRatio(
        uint160 sqrtPriceX96,
        uint8 decimal
    ) external pure returns (uint256) {
        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 numerator2 = 10 ** decimal;
        uint256 denominator = 1 << 192;

        return (numerator1 * numerator2) / denominator;
    }
}
