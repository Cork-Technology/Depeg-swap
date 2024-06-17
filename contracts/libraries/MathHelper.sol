// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library MathHelper {
    /// @dev default decimals for now to calculate price ratio
    uint8 internal constant DEFAULT_DECIMAL = 18;

    /**
     * @dev calculate the amount of wa and ct needed to provide AMM with liquidity in respect to the price ratio
     *
     * @param amountWa the total amount of liquidity user provide(e.g 2 WA)
     * @param priceRatio the price ratio of the pair, should be retrieved from the AMM as sqrtx96 and be converted to ratio
     * @return wa the amount of wa needed to provide AMM with liquidity
     * @return ct the amount of ct needed to provide AMM with liquidity, also the amount of how much wa should be converted to ct
     */
    function calculateAmounts(
        uint256 amountWa,
        uint256 priceRatio
    ) external pure returns (uint256 wa, uint256 ct) {
        ct = (amountWa * 1e18) / (priceRatio + 1e18);
        wa = (amountWa - ct);

        assert((ct + wa) == amountWa);
    }

    // TODO: add support for 2 different decimals token? but since we're
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

    /**
     * calculate the early lv rate in respect to the amount given
     * @param lvWaBalance the total amount of wa in the lv
     * @param totalLv the total amount of lv in the pool
     * @param amount the amount of lv user want to withdraw
     */
    function calculateEarlyLvRate(
        uint256 lvWaBalance,
        uint256 totalLv,
        uint256 amount
    ) external pure returns (uint256 received) {
        received = (amount * ((lvWaBalance * 1e18) / totalLv)) / 1e18;
    }

    /**
     * @dev calculate the fee in respect to the amount given
     * @param fee1e8 the fee in 1e8
     * @param amount the amount of lv user want to withdraw
     */
    function calculatePrecentageFee(
        uint256 fee1e8,
        uint256 amount
    ) external pure returns (uint256 precentage) {
        precentage = (((amount * 1e18) * fee1e8) / (100 * 1e18)) / 1e18;
    }

    function calculateRedeemAmountWithExchangeRate(
        uint256 amount,
        uint256 exchangeRate
    ) external pure returns (uint256) {
        return (amount * exchangeRate) / 1e18;
    }

    // TODO : unit test this, just move here from psm
    /// @notice calculate the accrued RA
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the PSM.
    ///
    /// amount * (&RA-#WA)/#CT)
    function calculateAccruedRa(
        uint256 amount,
        uint256 availableRa,
        uint256 totalWa,
        uint256 totalCtIssued
    ) internal pure returns (uint256 accrued) {
        accrued = amount * ((availableRa - totalWa) / totalCtIssued);
    }

    // TODO : unit test this, just move here from psm
    /// @notice calculate the accrued PA
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the PSM.
    ///
    /// amount * (&PA/#CT)
    function calculateAccruedPa(
        uint256 amount,
        uint256 availablePa,
        uint256 totalCtIssued
    ) internal pure returns (uint256 accrued) {
        accrued = amount * (availablePa / totalCtIssued);
    }
}
