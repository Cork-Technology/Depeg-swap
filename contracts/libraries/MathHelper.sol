// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {BuyMathBisectionSolver, SwapperMathLibrary} from "./DsSwapperMathLib.sol";
import {UD60x18, convert, ud, add, mul, pow, sub, div, unwrap, intoSD59x18} from "@prb/math/src/UD60x18.sol";
import {intoUD60x18} from "@prb/math/src/SD59x18.sol";
import {IErrors} from "./../interfaces/IErrors.sol";

/**
 * @title MathHelper Library Contract
 * @author Cork Team
 * @notice MathHelper Library which implements Helper functions for Math
 */
library MathHelper {
    /// @dev default decimals for now to calculate price ratio
    uint8 internal constant DEFAULT_DECIMAL = 18;

    // this is used to calculate tolerance level when adding liqudity to AMM pair
    /// @dev 1e18 == 1%.
    uint256 internal constant UNI_STATIC_TOLERANCE = 95e18;

    uint256 internal constant CT_PRICE_THRESHOLD = 1.05 ether;

    /**
     * @dev calculate the amount of ra and ct needed to provide AMM with liquidity in respect to the price ratio
     *
     * @param amountra the total amount of liquidity user provide(e.g 2 ra)
     * @param priceRatio the price ratio of the pair
     * @param raDecimals the number of decimals for the RA token
     * @return ra the amount of ra needed to provide AMM with liquidity
     * @return ct the amount of ct needed to provide AMM with liquidity, also the amount of how much ra should be converted to ct
     */
    function calculateProvideLiquidityAmountBasedOnCtPrice(uint256 amountra, uint256 priceRatio, uint8 raDecimals)
        external
        pure
        returns (uint256 ra, uint256 ct)
    {
        // Convert RA amount to 18 decimals for calculation if needed
        uint256 amountraAdjusted = amountra;
        if (raDecimals != DEFAULT_DECIMAL) {
            if (raDecimals < DEFAULT_DECIMAL) {
                amountraAdjusted = amountra * 10 ** (DEFAULT_DECIMAL - raDecimals);
            } else {
                amountraAdjusted = amountra / 10 ** (raDecimals - DEFAULT_DECIMAL);
            }
        }

        UD60x18 _ct = div(ud(amountraAdjusted), ud(priceRatio) + convert(1));
        ct = unwrap(_ct);

        // Convert RA back to original decimals if needed
        uint256 raAdjusted = amountraAdjusted - ct;
        if (raDecimals != DEFAULT_DECIMAL) {
            if (raDecimals < DEFAULT_DECIMAL) {
                ra = raAdjusted / 10 ** (DEFAULT_DECIMAL - raDecimals);
            } else {
                ra = raAdjusted * 10 ** (raDecimals - DEFAULT_DECIMAL);
            }
        } else {
            ra = raAdjusted;
        }
    }

    /**
     * @dev amount = pa x exchangeRate
     * calculate how much DS(need to be provided) and RA(user will receive) in respect to the exchange rate
     * @param pa the amount of pa user provides
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     * @return amount the amount of RA user will receive & DS needs to be provided
     */
    function calculateEqualSwapAmount(uint256 pa, uint256 exchangeRate) external pure returns (uint256 amount) {
        amount = unwrap(mul(ud(pa), ud(exchangeRate)));
    }

    function calculateProvideLiquidityAmount(uint256 amountRa, uint256 raDeposited) external pure returns (uint256) {
        return amountRa - raDeposited;
    }

    /**
     * @dev calculate the fee in respect to the amount given
     * @param fee1e18 the fee in 1e18
     * @param amount the amount of lv user want to withdraw
     */
    function calculatePercentageFee(uint256 fee1e18, uint256 amount) external pure returns (uint256 percentage) {
        UD60x18 fee = SwapperMathLibrary.calculatePercentage(ud(amount), ud(fee1e18));
        return unwrap(fee);
    }

    /**
     * @dev calcualte how much ct + ds user will receive based on the amount of the current exchange rate
     * @param amount  the amount of user  deposit
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     */
    function calculateDepositAmountWithExchangeRate(uint256 amount, uint256 exchangeRate)
        public
        pure
        returns (uint256)
    {
        UD60x18 _amount = div(ud(amount), ud(exchangeRate));
        return unwrap(_amount);
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
        UD60x18 _accrued = mul(ud(amount), div(ud(available), ud(totalCtIssued)));
        return unwrap(_accrued);
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
        UD60x18 _ratePerLv = div(ud(totalAmount), ud(totalLvIssued));

        UD60x18 _attributedWithdrawal = mul(_ratePerLv, ud(totalLvWithdrawn));

        UD60x18 _attributedAmm = sub(ud(totalAmount), _attributedWithdrawal);

        attributedWithdrawal = unwrap(_attributedWithdrawal);
        attributedAmm = unwrap(_attributedAmm);
        ratePerLv = unwrap(_ratePerLv);
    }

    function calculateWithTolerance(uint256 ra, uint256 ct, uint256 tolerance)
        external
        pure
        returns (uint256 raTolerance, uint256 ctTolerance)
    {
        UD60x18 _raTolerance = div(mul(ud(ra), ud(tolerance)), convert(100));
        UD60x18 _ctTolerance = div(mul(ud(ct), ud(tolerance)), convert(100));

        return (unwrap(_raTolerance), unwrap(_ctTolerance));
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
        UniLpValueParams memory params = UniLpValueParams(
            ud(totalLpSupply), ud(totalLpOwned), ud(totalRaReserve), ud(totalCtReserve), ud(totalLvIssued)
        );

        UniLpValueResult memory result = _calculateLvValueFromUniLp(params);

        raValuePerLv = unwrap(result.raValuePerLv);
        ctValuePerLv = unwrap(result.ctValuePerLv);
        valueRaPerLp = unwrap(result.valueRaPerLp);
        valueCtPerLp = unwrap(result.valueCtPerLp);
        totalLvRaValue = unwrap(result.totalLvRaValue);
        totalLvCtValue = unwrap(result.totalLvCtValue);
    }

    struct UniLpValueParams {
        UD60x18 totalLpSupply;
        UD60x18 totalLpOwned;
        UD60x18 totalRaReserve;
        UD60x18 totalCtReserve;
        UD60x18 totalLvIssued;
    }

    struct UniLpValueResult {
        UD60x18 raValuePerLv;
        UD60x18 ctValuePerLv;
        UD60x18 valueRaPerLp;
        UD60x18 valueCtPerLp;
        UD60x18 totalLvRaValue;
        UD60x18 totalLvCtValue;
    }

    function _calculateLvValueFromUniLp(UniLpValueParams memory params)
        internal
        pure
        returns (UniLpValueResult memory result)
    {
        (result.valueRaPerLp, result.valueCtPerLp) =
            calculateUniLpValue(params.totalLpSupply, params.totalRaReserve, params.totalCtReserve);

        UD60x18 cumulatedLptotalLvOwnedRa = mul(params.totalLpOwned, result.valueRaPerLp);
        UD60x18 cumulatedLptotalLvOwnedCt = mul(params.totalLpOwned, result.valueCtPerLp);

        result.raValuePerLv = div(cumulatedLptotalLvOwnedRa, params.totalLvIssued);
        result.ctValuePerLv = div(cumulatedLptotalLvOwnedCt, params.totalLvIssued);

        result.totalLvRaValue = mul(result.raValuePerLv, params.totalLvIssued);
        result.totalLvCtValue = mul(result.ctValuePerLv, params.totalLvIssued);
    }

    function convertToLp(uint256 rateRaPerLv, uint256 rateRaPerLp, uint256 redeemedLv)
        external
        pure
        returns (uint256 lpLiquidated)
    {
        lpLiquidated = ((redeemedLv * rateRaPerLv) * 1e18) / rateRaPerLp / 1e18;
    }

    struct NavParams {
        uint256 reserveRa;
        uint256 reserveCt;
        uint256 oneMinusT;
        uint256 lpSupply;
        uint256 lvSupply;
        uint256 vaultCt;
        uint256 vaultDs;
        uint256 vaultLp;
        uint256 vaultIdleRa;
    }

    function calculateDepositLv(uint256 nav, uint256 depositAmount, uint256 lvSupply)
        external
        pure
        returns (uint256 lvMinted)
    {
        if (nav == 0 || lvSupply == 0) return depositAmount;

        UD60x18 navPerShare = div(ud(nav), ud(lvSupply));

        return unwrap(div(ud(depositAmount), navPerShare));
    }

    function calculateNav(NavParams calldata params) external pure returns (uint256 nav) {
        (UD60x18 navLp, UD60x18 navCt, UD60x18 navDs, UD60x18 navIdleRas) = calculateNavCombined(params);

        nav = unwrap(add(navCt, add(navDs, navLp)));
        nav = unwrap(add(ud(nav), navIdleRas));
    }

    struct InternalPrices {
        UD60x18 ctPrice;
        UD60x18 dsPrice;
        UD60x18 raPrice;
    }

    function calculateInternalPrice(NavParams memory params) internal pure returns (InternalPrices memory) {
        UD60x18 t = sub(convert(1), ud(params.oneMinusT));
        UD60x18 ctPrice = calculatePriceQuote(ud(params.reserveRa), ud(params.reserveCt), t);

        if (ctPrice > ud(CT_PRICE_THRESHOLD)) revert IErrors.InvalidPoolStateOrNearExpired();

        // we set the default ds price to 0 if for some reason the ct price is worth above 1 RA
        // if not, this'll trigger an underflow error
        UD60x18 dsPrice = ctPrice > convert(1) ? ud(0) : sub(convert(1), ctPrice);
        // we're pricing RA in term of itself
        UD60x18 raPrice = convert(1);

        return InternalPrices(ctPrice, dsPrice, raPrice);
    }

    function calculateNavCombined(NavParams memory params)
        internal
        pure
        returns (UD60x18 navLp, UD60x18 navCt, UD60x18 navDs, UD60x18 navIdleRa)
    {
        InternalPrices memory prices = calculateInternalPrice(params);

        navCt = calculateNav(prices.ctPrice, ud(params.vaultCt));
        navDs = calculateNav(prices.dsPrice, ud(params.vaultDs));

        UD60x18 raPerLp = div(ud(params.reserveRa), ud(params.lpSupply));
        UD60x18 navRaLp = calculateNav(prices.raPrice, mul(ud(params.vaultLp), raPerLp));

        UD60x18 ctPerLp = div(ud(params.reserveCt), ud(params.lpSupply));
        UD60x18 navCtLp = calculateNav(prices.ctPrice, mul(ud(params.vaultLp), ctPerLp));

        navIdleRa = calculateNav(prices.raPrice, ud(params.vaultIdleRa));

        navLp = add(navRaLp, navCtLp);
    }

    struct RedeemParams {
        uint256 amountLvClaimed;
        uint256 totalLvIssued;
        uint256 totalVaultLp;
        uint256 totalVaultCt;
        uint256 totalVaultDs;
        uint256 totalVaultPA;
        uint256 totalVaultIdleRa;
    }

    struct RedeemResult {
        uint256 ctReceived;
        uint256 dsReceived;
        uint256 lpLiquidated;
        uint256 paReceived;
        uint256 idleRaReceived;
    }

    function calculateRedeemLv(RedeemParams calldata params) external pure returns (RedeemResult memory result) {
        UD60x18 proportionalClaim = div(ud(params.amountLvClaimed), ud(params.totalLvIssued));

        result.ctReceived = unwrap(mul(proportionalClaim, ud(params.totalVaultCt)));
        result.dsReceived = unwrap(mul(proportionalClaim, ud(params.totalVaultDs)));
        result.lpLiquidated = unwrap(mul(proportionalClaim, ud(params.totalVaultLp)));
        result.paReceived = unwrap(mul(proportionalClaim, ud(params.totalVaultPA)));
        result.idleRaReceived = unwrap(mul(proportionalClaim, ud(params.totalVaultIdleRa)));
    }

    /// @notice InitialctRatio = f / (rate +1)^t
    /// where f = 1, and t = 1
    /// we expect that the rate is in 1e18 precision BEFORE passing it to this function
    function calculateInitialCtRatio(uint256 _rate) internal pure returns (uint256) {
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
    function calculatePriceQuote(UD60x18 reserve0, UD60x18 reserve1, UD60x18 t) internal pure returns (UD60x18) {
        return pow(div(reserve0, reserve1), t);
    }

    function calculateNav(UD60x18 marketValueFromQuote, UD60x18 qty) internal pure returns (UD60x18) {
        return mul(marketValueFromQuote, qty);
    }
}
