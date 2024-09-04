pragma solidity 0.8.24;

/**
 * @title MathHelper Library Contract
 * @author Cork Team
 * @notice MathHelper Library which implements Helper functions for Math
 */
library MathHelper {
    uint224 internal constant Q112 = 2 ** 112;

    /// @dev default decimals for now to calculate price ratio
    uint8 internal constant DEFAULT_DECIMAL = 18;

    // this is used to calculate tolerance level when adding liqudity to AMM pair
    /// @dev 1e18 == 1%.
    uint256 internal constant UNIV2_STATIC_TOLERANCE = 1e18;

    /**
     * @dev calculate the amount of ra and ct needed to provide AMM with liquidity in respect to the price ratio
     *
     * @param amountra the total amount of liquidity user provide(e.g 2 ra)
     * @param priceRatio the price ratio of the pair, should be retrieved from the AMM as sqrtx96 and be converted to ratio
     * @return ra the amount of ra needed to provide AMM with liquidity
     * @return ct the amount of ct needed to provide AMM with liquidity, also the amount of how much ra should be converted to ct
     */
    function calculateProvideLiquidityAmountBasedOnCtPrice(uint256 amountra, uint256 priceRatio)
        external
        pure
        returns (uint256 ra, uint256 ct)
    {
        ct = (amountra * 1e18) / (priceRatio + 1e18);
        ra = (amountra - ct);

        assert((ct + ra) == amountra);
    }

    /// @dev should only pass ERC20.decimals() onto the decimal field
    /// @dev will output price ratio in 18 decimal precision.
    function calculatePriceRatioUniV4(uint160 sqrtPriceX96, uint8 decimal) external pure returns (uint256) {
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
    function calculateBaseWithdrawal(uint256 totalLv, uint256 accruedRa, uint256 accruedPa, uint256 amount)
        external
        pure
        returns (uint256 ra, uint256 pa)
    {
        ra = (amount * (accruedRa * 1e18) / totalLv) / 1e18;
        pa = (amount * (accruedPa * 1e18) / totalLv) / 1e18;
    }

    /**
     * calculate the early lv rate in respect to the amount given
     * @param lvRaBalance the total amount of ra in the lv
     * @param totalLv the total amount of lv in the pool
     * @param amount the amount of lv user want to withdraw
     */
    function calculateEarlyLvRate(uint256 lvRaBalance, uint256 totalLv, uint256 amount)
        external
        pure
        returns (uint256 received)
    {
        received = (amount * (lvRaBalance * 1e18) / totalLv) / 1e18;
    }

    /**
     * @dev calculate the fee in respect to the amount given
     * @param fee1e18 the fee in 1e18
     * @param amount the amount of lv user want to withdraw
     */
    function calculatePrecentageFee(uint256 fee1e18, uint256 amount) external pure returns (uint256 precentage) {
        precentage = (((amount * 1e18) * fee1e18) / (100 * 1e18)) / 1e18;
    }

    /**
     * @dev calcualte how much ct + ds user will receive based on the amount of the current exchange rate
     * @param amount  the amount of user  deposit
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     */
    function calculateDepositAmountWithExchangeRate(uint256 amount, uint256 exchangeRate)
        external
        pure
        returns (uint256 _amount)
    {
        _amount = (amount * 1e18) / exchangeRate;
    }

    /**
     * @dev caclulcate how much ra user will receive based on an exchange rate
     * @param amount the amount of ds user want to redeem
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     */
    function calculateRedeemAmountWithExchangeRate(uint256 amount, uint256 exchangeRate)
        external
        pure
        returns (uint256 _amount)
    {
        _amount = (amount * exchangeRate) / 1e18;
    }

    /// @notice calculate the accrued PA & RA
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the PSM.
    ///
    /// amount * (&PA or &RA/#CT)
    function calculateAccrued(uint256 amount, uint256 available, uint256 totalCtIssued)
        internal
        pure
        returns (uint256 accrued)
    {
        accrued = (amount * (available * 1e18) / totalCtIssued) / 1e18;
    }

    function separateLiquidity(uint256 totalAmount, uint256 totalLvIssued, uint256 totalLvWithdrawn)
        external
        pure
        returns (uint256 attributedWithdrawal, uint256 attributedAmm, uint256 ratePerLv)
    {
        // with 1e18 precision
        ratePerLv = ((totalAmount * 1e18) / totalLvIssued);

        // attribute all to AMM if no lv issued or withdrawn
        if (totalLvIssued == 0 || totalLvWithdrawn == 0) {
            return (0, totalAmount, ratePerLv);
        }

        attributedWithdrawal = (ratePerLv * totalLvWithdrawn) / 1e18;
        attributedAmm = totalAmount - attributedWithdrawal;

        assert((attributedWithdrawal + attributedAmm) == totalAmount);
    }

    function calculateWithTolerance(uint256 ra, uint256 ct, uint256 tolerance)
        external
        pure
        returns (uint256 raTolerance, uint256 ctTolerance)
    {
        raTolerance = ra - ((ra * 1e18 * tolerance) / (100 * 1e18) / 1e18);
        ctTolerance = ct - ((ct * 1e18 * tolerance) / (100 * 1e18) / 1e18);
    }

    function calculateUniV2LpValue(uint256 totalLpSupply, uint256 totalRaReserve, uint256 totalCtReserve)
        public
        pure
        returns (uint256 valueRaPerLp, uint256 valueCtPerLp)
    {
        valueRaPerLp = (uint256(totalRaReserve) * 1e18) / totalLpSupply;
        valueCtPerLp = (uint256(totalCtReserve) * 1e18) / totalLpSupply;
    }

    function calculateLvValueFromUniV2Lp(
        uint256 totalLpSupply,
        uint256 totalLpOwned,
        uint256 totalRaReserve,
        uint256 totalCtReserve,
        uint256 totalLvIssued
    )
        external
        pure
        returns (
            uint256 raValuePerLv,
            uint256 ctValuePerLv,
            uint256 valueRaPerLp,
            uint256 valueCtPerLp,
            uint256 totalLvRaValue,
            uint256 totalLvCtValue
        )
    {
        (valueRaPerLp, valueCtPerLp) = calculateUniV2LpValue(totalLpSupply, totalRaReserve, totalCtReserve);

        uint256 cumulatedLptotalLvOwnedRa = (totalLpOwned * valueRaPerLp) / 1e18;
        uint256 cumulatedLptotalLvOwnedCt = (totalLpOwned * valueCtPerLp) / 1e18;

        raValuePerLv = (cumulatedLptotalLvOwnedRa * 1e18) / totalLvIssued;
        ctValuePerLv = (cumulatedLptotalLvOwnedCt * 1e18) / totalLvIssued;

        totalLvRaValue = (raValuePerLv * totalLvIssued) / 1e18;
        totalLvCtValue = (ctValuePerLv * totalLvIssued) / 1e18;
    }

    function convertToLp(uint256 rateRaPerLv, uint256 rateRaPerLp, uint256 redeemedLv)
        external
        pure
        returns (uint256 lpLiquidated)
    {
        lpLiquidated = ((redeemedLv * rateRaPerLv) * 1e18) / rateRaPerLp / 1e18;
    }
}
