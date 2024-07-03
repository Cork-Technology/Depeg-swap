// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library MathHelper {
    /// @dev default decimals for now to calculate price ratio
    uint8 internal constant DEFAULT_DECIMAL = 18;

    /**
     * @dev calculate the amount of ra and ct needed to provide AMM with liquidity in respect to the price ratio
     *
     * @param amountra the total amount of liquidity user provide(e.g 2 ra)
     * @param priceRatio the price ratio of the pair, should be retrieved from the AMM as sqrtx96 and be converted to ratio
     * @return ra the amount of ra needed to provide AMM with liquidity
     * @return ct the amount of ct needed to provide AMM with liquidity, also the amount of how much ra should be converted to ct
     */
    function calculateAmounts(
        uint256 amountra,
        uint256 priceRatio
    ) external pure returns (uint256 ra, uint256 ct) {
        ct = (amountra * 1e18) / (priceRatio + 1e18);
        ra = (amountra - ct);

        assert((ct + ra) == amountra);
    }

    // TODO: add support for 2 different decimals token? but since we're
    // using ra and ct, which both has 18 decimals so will default into that one for now
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
        ra = (amount * ((accruedRa * 1e18) / totalLv)) / 1e18;
        pa = (amount * ((accruedPa * 1e18) / totalLv)) / 1e18;
    }


    /**
     * calculate the early lv rate in respect to the amount given
     * @param lvRaBalance the total amount of ra in the lv
     * @param totalLv the total amount of lv in the pool
     * @param amount the amount of lv user want to withdraw
     */
    function calculateEarlyLvRate(
        uint256 lvRaBalance,
        uint256 totalLv,
        uint256 amount
    ) external pure returns (uint256 received) {
        received = (amount * ((lvRaBalance * 1e18) / totalLv)) / 1e18;
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

    /**
     * @dev calcualte how much ct + ds user will receive based on the amount of the current exchange rate
     * @param amount  the amount of user  deposit
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     */
    function calculateDepositAmountWithExchangeRate(
        uint256 amount,
        uint256 exchangeRate
    ) external pure returns (uint256 _amount) {
        _amount = (amount * 1e18) / exchangeRate;
    }

    /**
     * @dev caclulcate how much ra user will receive when redeeming with x amount of ds based on the current exchange rate
     * @param amount the amount of ds user want to redeem
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     */
    function calculateRedeemAmountWithExchangeRate(
        uint256 amount,
        uint256 exchangeRate
    ) external pure returns (uint256 _amount) {
        _amount = (amount * exchangeRate) / 1e18;
    }

    // TODO : unit test this, just move here from psm
    /// @notice calculate the accrued PA & RA
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the PSM.
    ///
    /// amount * (&PA or &RA/#CT)
    function calculateAccrued(
        uint256 amount,
        uint256 available,
        uint256 totalCtIssued
    ) internal pure returns (uint256 accrued) {
        accrued = amount * (available / totalCtIssued);
    }

    function separateLiquidity(
        uint256 totalAmount,
        uint256 totalLvIssued,
        uint256 totalLvWithdrawn
    )
        internal
        pure
        returns (uint256 attributedWithdrawal, uint256 attributedAmm)
    {
        uint256 ratePerLv = totalAmount / totalLvIssued;
    }
}
