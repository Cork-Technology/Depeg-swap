// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library MathHelper {
    /// @dev default decimals for now to calculate price ratio
    uint8 internal constant DEFAULT_DECIMAL = 18;

    /**
     * @dev calculate the amount of wa and ct needed to provide AMM with liquidity in respect to the price ratio
     *
     * @param amount  the total amount of liquidity user provide(e.g 2 WA)
     * @param priceRatio the price ratio of the pair, should be retrieved from the AMM as sqrtx96 and be converted to ratio
     * @return amountWa the amount of wa needed to provide AMM with liquidity
     * @return amountCt the amount of ct needed to provide AMM with liquidity
     * @return leftoverWa the leftover wa after providing AMM with liquidit, should for now reside in the LV
     * @return leftoverCt the leftover ct after providing AMM with liquidit, should for now reside in the LV
     */
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

    /**
     *  @dev calculate the base withdrawal amount of ra and pa in respect of given amount
     * @param totalLv the total amount of lv in the pool
     * @param accruedRa the total amount of ra accrued in the pool  
     * @param accruedPa the total amount of pa accrued in the pool
     * @param amount the amount of lv user want to withdraw
     * @return ra the amount of ra user will receive
     * @return pa the amount of pa user will receive
     */
    function calculateBaseWithdrawal(
        uint256 totalLv,
        uint256 accruedRa,
        uint256 accruedPa,
        uint256 amount
    ) external pure returns (uint256 ra, uint256 pa) {
        (uint256 raPerLv, uint256 paPerLv) = calculateLvValue(
            totalLv,
            accruedRa,
            accruedPa
        );

        ra = (amount * raPerLv);
        pa = (amount * paPerLv);
    }

    /**
     * @dev calculate the value of ra and pa per lv
     * @param totalLv the total amount of lv in the pool
     * @param accruedRa the total amount of ra accrued in the pool
     * @param accruedPa the total amount of pa accrued in the pool
     * @return ra the value of ra per lv
     * @return pa the value of pa per lv
     */
    function calculateLvValue(
        uint256 totalLv,
        uint256 accruedRa,
        uint256 accruedPa
    ) internal pure returns (uint256 ra, uint256 pa) {
        ra = accruedRa / totalLv;
        pa = accruedPa / totalLv;
    }
}
