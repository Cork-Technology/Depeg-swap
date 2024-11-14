// TODO : change math related contract license to MIT/GPL
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {BuyMathBisectionSolver, SwapperMathLibrary} from "./DsSwapperMathLib.sol";

import {UD60x18, convert, ud, add, mul, pow, sub, div, unwrap, intoSD59x18} from "@prb/math/src/UD60x18.sol";
import {SD59x18, intoUD60x18} from "@prb/math/src/SD59x18.sol";
import "Cork-Hook/lib/MarketSnapshot.sol";

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
    uint256 internal constant UNIV2_STATIC_TOLERANCE = 5e18;

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
    }

    /**
     * @dev amount = pa x exchangeRate
     * calculate how much DS(need to be provided) and RA(user will receive) in respect to the exchange rate
     * @param pa the amount of pa user provides
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     * @return amount the amount of RA user will receive & DS needs to be provided
     */
    function calculateEqualSwapAmount(uint256 pa, uint256 exchangeRate) external pure returns (uint256 amount) {
        amount = (pa * exchangeRate) / 1e18;
    }

    function calculateProvideLiquidityAmount(uint256 amountRa, uint256 raDeposited) external pure returns (uint256) {
        return amountRa - raDeposited;
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
    function calculatePercentageFee(uint256 fee1e18, uint256 amount) external pure returns (uint256 percentage) {
        percentage = (((amount * 1e18) * fee1e18) / (100 * 1e18)) / 1e18;
    }

    /**
     * @dev calcualte how much ct + ds user will receive based on the amount of the current exchange rate
     * @param amount  the amount of user  deposit
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     */
    function calculateDepositAmountWithExchangeRate(uint256 amount, uint256 exchangeRate)
        public
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
        // attribute all to AMM if no lv issued or withdrawn
        if (totalLvIssued == 0 || totalLvWithdrawn == 0) {
            return (0, totalAmount, 0);
        }

        // with 1e18 precision
        ratePerLv = ((totalAmount * 1e18) / totalLvIssued);

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

    function calculateUniLpValue(UD60x18 totalLpSupply, UD60x18 totalRaReserve, UD60x18 totalCtReserve)
        public
        pure
        returns (UD60x18 valueRaPerLp, UD60x18 valueCtPerLp)
    {
        valueRaPerLp = div(totalRaReserve, totalLpSupply);
        valueCtPerLp = div(totalCtReserve, totalLpSupply);
    }

    function calculateLvValueFromUniLp(
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
        // (valueRaPerLp, valueCtPerLp) = calculateUniLpValue(totalLpSupply, totalRaReserve, totalCtReserve);

        uint256 cumulatedLptotalLvOwnedRa = (totalLpOwned * valueRaPerLp) / 1e18;
        uint256 cumulatedLptotalLvOwnedCt = (totalLpOwned * valueCtPerLp) / 1e18;

        raValuePerLv = (cumulatedLptotalLvOwnedRa * 1e18) / totalLvIssued;
        ctValuePerLv = (cumulatedLptotalLvOwnedCt * 1e18) / totalLvIssued;

        totalLvRaValue = (raValuePerLv * totalLvIssued) / 1e18;
        totalLvCtValue = (ctValuePerLv * totalLvIssued) / 1e18;
    }

    // struct UniLpValueParams {
    //     UD60x18 totalLpSupply;
    //     UD60x18 totalLpOwned;
    //     UD60x18 totalRaReserve;
    //     UD60x18 totalCtReserve;
    //     UD60x18 totalLvIssued;
    // }

    // struct UniLpValueResult {
    //     UD60x18 raValuePerLv;
    //     UD60x18 ctValuePerLv;
    //     UD60x18 valueRaPerLp;
    //     UD60x18 valueCtPerLp;
    //     UD60x18 totalLvRaValue;
    //     UD60x18 totalLvCtValue;
    // }

    // function _calculateLvValueFromUniLp(UniLpValueParams memory params)
    //     external
    //     pure
    //     returns (UniLpValueResult memory result)
    // {
    //     (result.valueRaPerLp, result.valueCtPerLp) = calculateUniLpValue(totalLpSupply, totalRaReserve, totalCtReserve);

    //     UD60x18 cumulatedLptotalLvOwnedRa = mul(totalLpOwned, valueRaPerLp);
    //     UD60x18 cumulatedLptotalLvOwnedCt = mul(totalLpOwned, valueCtPerLp);

    //     raValuePerLv = (cumulatedLptotalLvOwnedRa * 1e18) / totalLvIssued;
    //     ctValuePerLv = (cumulatedLptotalLvOwnedCt * 1e18) / totalLvIssued;

    //     totalLvRaValue = (raValuePerLv * totalLvIssued) / 1e18;
    //     totalLvCtValue = (ctValuePerLv * totalLvIssued) / 1e18;
    // }

    function convertToLp(uint256 rateRaPerLv, uint256 rateRaPerLp, uint256 redeemedLv)
        external
        pure
        returns (uint256 lpLiquidated)
    {
        lpLiquidated = ((redeemedLv * rateRaPerLv) * 1e18) / rateRaPerLp / 1e18;
    }

    struct DepositParams {
        uint256 depositAmount;
        uint256 reserveRa;
        uint256 reserveCt;
        uint256 oneMinusT;
        uint256 lpSupply;
        uint256 lvSupply;
        uint256 vaultCt;
        uint256 vaultDs;
        uint256 vaultLp;
    }

    function calculateDepositLv(DepositParams memory params) external pure returns (uint256 lvMinted) {
        (UD60x18 navLp, UD60x18 navCt, UD60x18 navDs) = calculateNavCombined(params);

        UD60x18 nav = add(navCt, add(navDs, navLp));
        UD60x18 navPerShare = div(nav, ud(params.lvSupply));

        return unwrap(div(ud(params.depositAmount), navPerShare));
    }

    struct InternalPrices {
        UD60x18 ctPrice;
        UD60x18 dsPrice;
        UD60x18 raPrice;
    }

    function calculateInternalPrice(DepositParams memory params) internal pure returns (InternalPrices memory) {
        UD60x18 t = sub(convert(1), ud(params.oneMinusT));
        UD60x18 ctPrice = caclulatePriceQuote(ud(params.reserveRa), ud(params.reserveCt), t);
        UD60x18 dsPrice = sub(convert(1), ctPrice);
        UD60x18 raPrice = caclulatePriceQuote(ud(params.reserveCt), ud(params.reserveRa), t);

        return InternalPrices(ctPrice, dsPrice, raPrice);
    }

    function calculateNavCombined(DepositParams memory params)
        internal
        pure
        returns (UD60x18 navLp, UD60x18 navCt, UD60x18 navDs)
    {
        InternalPrices memory prices = calculateInternalPrice(params);

        navCt = calculateNav(prices.ctPrice, ud(params.vaultCt));
        navDs = calculateNav(prices.dsPrice, ud(params.vaultDs));

        UD60x18 raPerLp = div(ud(params.lpSupply), ud(params.reserveRa));
        UD60x18 navRaLp = calculateNav(prices.raPrice, mul(ud(params.vaultLp), raPerLp));

        UD60x18 ctPerLp = div(ud(params.lpSupply), ud(params.reserveCt));
        UD60x18 navCtLp = calculateNav(prices.ctPrice, mul(ud(params.vaultLp), ctPerLp));

        navLp = add(navRaLp, navCtLp);
    }

    struct RedeemParams {
        uint256 amountLvClaimed;
        uint256 totalLvIssued;
        uint256 totalVaultLp;
        uint256 totalVaultCt;
        uint256 totalVaultDs;
    }

    function calculateRedeemLv(RedeemParams calldata params)
        external
        pure
        returns (uint256 ctReceived, uint256 dsReceived, uint256 lpLiquidated)
    {
        UD60x18 proportionalClaim = div(ud(params.amountLvClaimed), ud(params.totalLvIssued));
        ctReceived = unwrap(mul(proportionalClaim, ud(params.totalVaultCt)));
        dsReceived = unwrap(mul(proportionalClaim, ud(params.totalVaultDs)));
        lpLiquidated = unwrap(mul(proportionalClaim, ud(params.totalVaultLp)));
    }

    /// @notice InitialctRatio = f / (rate +1)^t
    /// where f = 1, and t = 1
    /// we expect that the rate is in 1e18 precision BEFORE passing it to this function
    function caclulateInitialCtRatio(uint256 _rate) internal pure returns (uint256) {
        UD60x18 rate = convert(_rate);
        // normalize to 0-1
        rate = div(rate, convert(100));

        UD60x18 ratePlusOne = add(convert(1e18), rate);
        return convert(div(convert(1e36), ratePlusOne));
    }

    function calculateRepurchaseFee(
        uint256 _start,
        uint256 _end,
        uint256 _current,
        uint256 _amount,
        uint256 _baseFeePercentage
    ) internal pure returns (uint256 _fee, uint256 _actualFeePercentage) {
        UD60x18 t = intoUD60x18(
            BuyMathBisectionSolver.computeT(
                intoSD59x18(convert(_start)), intoSD59x18(convert(_end)), intoSD59x18(convert(_current))
            )
        );

        UD60x18 feeFactor = mul(convert(_baseFeePercentage), t);
        // since the amount is already on 18 decimals, we don't need to convert it
        UD60x18 fee = SwapperMathLibrary.calculatePercentage(ud(_amount), feeFactor);

        _actualFeePercentage = convert(feeFactor);
        _fee = convert(fee);
    }

    /// @notice calculates quote = (reserve0 / reserve1)^t
    function caclulatePriceQuote(UD60x18 reserve0, UD60x18 reserve1, UD60x18 t) internal pure returns (UD60x18) {
        return pow(div(reserve0, reserve1), t);
    }

    function calculateNav(UD60x18 marketValueFromQuote, UD60x18 qty) internal pure returns (UD60x18) {
        return mul(marketValueFromQuote, qty);
    }
}
