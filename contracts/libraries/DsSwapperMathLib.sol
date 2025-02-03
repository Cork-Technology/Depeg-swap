// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {SD59x18, convert, sd, add, mul, pow, sub, div, abs, unwrap, intoUD60x18} from "@prb/math/src/SD59x18.sol";
import {UD60x18, convert as convertUd, ud, add, mul, pow, sub, div, unwrap} from "@prb/math/src/UD60x18.sol";
import {IErrors} from "./../interfaces/IErrors.sol";
import {MarketSnapshot, MarketSnapshotLib} from "Cork-Hook/lib/MarketSnapshot.sol";
import {TransferHelper} from "./TransferHelper.sol";
import {LogExpMath} from "./LogExpMath.sol";

library BuyMathBisectionSolver {
    /// @notice returns the the normalized time to maturity from 1-0
    /// 1 means we're at the start of the period, 0 means we're at the end
    function computeT(SD59x18 start, SD59x18 end, SD59x18 current) public pure returns (SD59x18) {
        SD59x18 minimumElapsed = convert(1);

        SD59x18 elapsedTime = sub(current, start);
        elapsedTime = elapsedTime == convert(0) ? minimumElapsed : elapsedTime;
        SD59x18 totalDuration = sub(end, start);

        // we return 0 in case it's past maturity time
        if (elapsedTime >= totalDuration) {
            return convert(0);
        }

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        return sub(convert(1), div(elapsedTime, totalDuration));
    }

    function computeOneMinusT(SD59x18 start, SD59x18 end, SD59x18 current) public pure returns (SD59x18) {
        return sub(convert(1), computeT(start, end, current));
    }

    /// @notice f(s) = x^1-t + y^t - (x - s + e)^1-t - (y + s)^1-t
    function f(SD59x18 x, SD59x18 y, SD59x18 e, SD59x18 s, SD59x18 oneMinusT) public pure returns (SD59x18) {
        SD59x18 xMinSplusE = sub(x, s);
        xMinSplusE = add(xMinSplusE, e);

        SD59x18 yPlusS = add(y, s);

        {
            SD59x18 zero = convert(0);

            if (xMinSplusE < zero && yPlusS < zero) {
                revert IErrors.InvalidS();
            }
        }

        SD59x18 xPow = _pow(x, oneMinusT);
        SD59x18 yPow = _pow(y, oneMinusT);
        SD59x18 xMinSplusEPow = _pow(xMinSplusE, oneMinusT);
        SD59x18 yPlusSPow = _pow(yPlusS, oneMinusT);

        return sub(sub(add(xPow, yPow), xMinSplusEPow), yPlusSPow);
    }

    // more gas efficient than PRB
    function _pow(SD59x18 x, SD59x18 y) public pure returns (SD59x18) {
        uint256 _x = uint256(unwrap(x));
        uint256 _y = uint256(unwrap(y));

        return sd(int256(LogExpMath.pow(_x, _y)));
    }

    function findRoot(SD59x18 x, SD59x18 y, SD59x18 e, SD59x18 oneMinusT, SD59x18 epsilon, uint256 maxIter)
        public
        pure
        returns (SD59x18)
    {
        SD59x18 a = sd(0);
        SD59x18 b;

        {
            SD59x18 delta = sd(1e6);
            b = sub(add(x, e), delta);
        }

        SD59x18 fA = f(x, y, e, a, oneMinusT);
        SD59x18 fB = f(x, y, e, b, oneMinusT);
        {
            if (mul(fA, fB) >= sd(0)) {
                uint256 maxAdjustments = 1000;

                SD59x18 adjustment = mul(convert(-1e4), b);
                for (uint256 i = 0; i < maxAdjustments; ++i) {
                    b = sub(b, adjustment);
                    fB = f(x, y, e, b, oneMinusT);

                    if (mul(fA, fB) < sd(0)) {
                        break;
                    }
                }

                revert IErrors.NoSignChange();
            }
        }

        for (uint256 i = 0; i < maxIter; ++i) {
            SD59x18 c = div(add(a, b), convert(2));
            SD59x18 fC = f(x, y, e, c, oneMinusT);

            if (abs(fC) < epsilon) {
                return c;
            }

            if (mul(fA, fC) < sd(0)) {
                b = c;
                fB = fC;
            } else {
                a = c;
                fA = fC;
            }

            if (sub(b, a) < epsilon) {
                return div(add(a, b), convert(2));
            }
        }

        revert IErrors.NoConverge();
    }
}

/**
 * @title SwapperMathLibrary Contract
 * @author Cork Team
 * @notice SwapperMath library which implements math operations for DS swap contract
 */
library SwapperMathLibrary {
    using MarketSnapshotLib for MarketSnapshot;

    // needed since, if it's near expiry and the value goes higher than this,
    // the math would fail, since near expiry it would behave similar to CSM curve,
    // it's fine if the actual value go higher since that means we would only overestimate on how much we actually need to repay
    int256 internal constant ONE_MINUS_T_CAP = 99e17;

    // Calculate price ratio of two tokens in AMM, will return ratio on 18 decimals precision
    function getPriceRatio(uint256 raReserve, uint256 ctReserve)
        public
        pure
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        if (raReserve <= 0 || ctReserve <= 0) {
            revert IErrors.ZeroReserve();
        }

        raPriceRatio = unwrap(div(ud(ctReserve), ud(raReserve)));
        ctPriceRatio = unwrap(div(ud(raReserve), ud(ctReserve)));
    }

    // calculate the realized fee of a RA to DS swap
    function calculateDsExtraFee(uint256 amount, uint256 salePercentage, uint256 feePercentage)
        internal
        pure
        returns (uint256 fee)
    {
        fee = calculatePercentage(amount, salePercentage);
        fee = calculatePercentage(fee, feePercentage);
    }

    function getAmountOutBuyDs(
        uint256 x,
        uint256 y,
        uint256 e,
        uint256 start,
        uint256 end,
        uint256 current,
        uint256 epsilon,
        uint256 maxIter
    ) external pure returns (uint256 s) {
        if (e > x && x < y) {
            revert IErrors.InsufficientLiquidityForSwap();
        }

        SD59x18 oneMinusT = BuyMathBisectionSolver.computeOneMinusT(
            convert(int256(start)), convert(int256(end)), convert(int256(current))
        );

        if (unwrap(oneMinusT) > ONE_MINUS_T_CAP) {
            oneMinusT = sd(ONE_MINUS_T_CAP);
        }

        SD59x18 root = BuyMathBisectionSolver.findRoot(
            convert(int256(x)), convert(int256(y)), convert(int256(e)), oneMinusT, sd(int256(epsilon)), maxIter
        );

        return uint256(convert(root));
    }

    function calculatePercentage(UD60x18 amount, UD60x18 percentage) internal pure returns (UD60x18 result) {
        result = div(mul(amount, percentage), convertUd(100));
    }

    function calculatePercentage(uint256 amount, uint256 percentage) internal pure returns (uint256 result) {
        result = unwrap(calculatePercentage(ud(amount), ud(percentage)));
    }

    /// @notice HIYA_acc = Ri x Volume_i x 1 - ((Discount / 86400) * (currentTime - issuanceTime))
    function calcHIYAaccumulated(
        uint256 startTime,
        uint256 maturityTime,
        uint256 currentTime,
        uint256 amount,
        uint256 raProvided,
        uint256 decayDiscountInDays
    ) external pure returns (uint256) {
        UD60x18 t = intoUD60x18(
            BuyMathBisectionSolver.computeT(
                convert(int256(startTime)), convert(int256(maturityTime)), convert(int256(currentTime))
            )
        );
        UD60x18 effectiveDsPrice = calculateEffectiveDsPrice(ud(amount), ud(raProvided));
        UD60x18 rateI = calcSpotArp(t, effectiveDsPrice);
        UD60x18 decay = calculateDecayDiscount(ud(decayDiscountInDays), ud(startTime), ud(currentTime));

        return unwrap(calculatePercentage(calculatePercentage(ud(amount), rateI), decay));
    }

    /// @notice VHIYA_acc =  Volume_i  - ((Discount / 86400) * (currentTime - issuanceTime))
    function calcVHIYAaccumulated(uint256 startTime, uint256 currentTime, uint256 decayDiscountInDays, uint256 amount)
        external
        pure
        returns (uint256)
    {
        UD60x18 decay = calculateDecayDiscount(ud(decayDiscountInDays), ud(startTime), ud(currentTime));

        return convertUd(calculatePercentage(convertUd(amount), decay));
    }

    function calculateEffectiveDsPrice(UD60x18 dsAmount, UD60x18 raProvided)
        internal
        pure
        returns (UD60x18 effectiveDsPrice)
    {
        effectiveDsPrice = div(raProvided, dsAmount);
    }

    function calculateHIYA(uint256 cumulatedHIYA, uint256 cumulatedVHIYA) external pure returns (uint256 hiya) {
        // we unwrap here since we want to keep the precision when storing
        hiya = unwrap(div(convertUd(cumulatedHIYA), convertUd(cumulatedVHIYA)));
    }

    /**
     * decay = 100 - ((Discount / 86400) * (currentTime - issuanceTime))
     * requirements :
     * Discount * (currentTime - issuanceTime) < 100
     */
    function calculateDecayDiscount(UD60x18 decayDiscountInDays, UD60x18 issuanceTime, UD60x18 currentTime)
        internal
        pure
        returns (UD60x18 decay)
    {
        UD60x18 discPerSec = div(decayDiscountInDays, convertUd(86400));
        UD60x18 t = sub(currentTime, issuanceTime);
        UD60x18 discount = mul(discPerSec, t);

        // this must hold true, it doesn't make sense to have a discount above 100%
        assert(discount < convertUd(100));
        decay = sub(convertUd(100), discount);
    }

    function _calculateRolloverSale(UD60x18 lvDsReserve, UD60x18 psmDsReserve, UD60x18 raProvided, UD60x18 hpa)
        public
        view
        returns (
            UD60x18 lvProfit,
            UD60x18 psmProfit,
            UD60x18 raLeft,
            UD60x18 dsReceived,
            UD60x18 lvReserveUsed,
            UD60x18 psmReserveUsed
        )
    {
        UD60x18 totalDsReserve = add(lvDsReserve, psmDsReserve);

        // calculate the amount of DS user will receive
        dsReceived = div(raProvided, hpa);

        // returns the RA if, the total reserve cannot cover the DS that user will receive. this Ra left must subject to the AMM rates
        if (totalDsReserve >= dsReceived) {
            raLeft = convertUd(0); // No shortfall
        } else {
            // Adjust the DS received to match the total reserve
            dsReceived = totalDsReserve;

            // Recalculate raLeft to account for the dust
            raLeft = sub(raProvided, mul(dsReceived, hpa));
        }

        // recalculate the DS user will receive, after the RA left is deducted
        raProvided = sub(raProvided, raLeft);

        // proportionally calculate how much DS should be taken from LV and PSM
        // e.g if LV has 60% of the total reserve, then 60% of the DS should be taken from LV
        lvReserveUsed = div(mul(lvDsReserve, dsReceived), totalDsReserve);
        psmReserveUsed = sub(dsReceived, lvReserveUsed);

        assert(unwrap(dsReceived) == unwrap(psmReserveUsed + lvReserveUsed));

        if (psmReserveUsed > psmDsReserve) {
            UD60x18 diff = sub(psmReserveUsed, psmDsReserve);
            psmReserveUsed = sub(psmReserveUsed, diff);
            lvReserveUsed = add(lvReserveUsed, diff);
        }

        if (lvReserveUsed > lvDsReserve) {
            UD60x18 diff = sub(lvReserveUsed, lvDsReserve);
            lvReserveUsed = sub(lvReserveUsed, diff);
            psmReserveUsed = add(psmReserveUsed, diff);
        }

        assert(totalDsReserve >= lvReserveUsed + psmReserveUsed);

        // calculate the RA profit of LV and PSM
        lvProfit = mul(lvReserveUsed, hpa);
        psmProfit = mul(psmReserveUsed, hpa);
    }

    function calculateRolloverSale(uint256 lvDsReserve, uint256 psmDsReserve, uint256 raProvided, uint256 hiya)
        external
        view
        returns (
            uint256 lvProfit,
            uint256 psmProfit,
            uint256 raLeft,
            uint256 dsReceived,
            uint256 lvReserveUsed,
            uint256 psmReserveUsed
        )
    {
        UD60x18 _lvDsReserve = ud(lvDsReserve);
        UD60x18 _psmDsReserve = ud(psmDsReserve);
        UD60x18 _raProvided = ud(raProvided);
        UD60x18 _hpa = sub(convertUd(1), calcPtConstFixed(ud(hiya)));

        (
            UD60x18 _lvProfit,
            UD60x18 _psmProfit,
            UD60x18 _raLeft,
            UD60x18 _dsReceived,
            UD60x18 _lvReserveUsed,
            UD60x18 _psmReserveUsed
        ) = _calculateRolloverSale(_lvDsReserve, _psmDsReserve, _raProvided, _hpa);

        lvProfit = unwrap(_lvProfit);
        psmProfit = unwrap(_psmProfit);
        raLeft = unwrap(_raLeft);
        dsReceived = unwrap(_dsReceived);
        lvReserveUsed = unwrap(_lvReserveUsed);
        psmReserveUsed = unwrap(_psmReserveUsed);
    }

    /**
     * @notice  e =  s - (x' - x)
     *          x' - x = (k - (reserveOut - amountOut)^(1-t))^1/(1-t) - reserveIn
     *          x' - x and x should be fetched directly from the hook
     *          x' - x is the same as regular getAmountIn
     * @param xIn the RA we must pay, get it from the hook using getAmountIn
     * @param s Amount DS user want to sell and how much CT we should borrow from the AMM and also the RA we receive from the PSM
     *
     * @return success true if the operation is successful, false otherwise. happen generally if there's insufficient liquidity
     * @return e Amount of RA user will receive
     */
    function getAmountOutSellDs(uint256 xIn, uint256 s) external pure returns (bool success, uint256 e) {
        if (s < xIn) {
            return (false, 0);
        } else {
            e = s - xIn;
            return (true, e);
        }
    }

    /// @notice rT = (f/pT)^1/t - 1
    function calcRt(UD60x18 pT, UD60x18 t) internal pure returns (UD60x18) {
        UD60x18 onePerT = div(convertUd(1), t);
        UD60x18 fConst = convertUd(1);

        UD60x18 fPerPt = div(fConst, pT);
        UD60x18 fPerPtPow = pow(fPerPt, onePerT);

        return sub(fPerPtPow, convertUd(1));
    }

    function calcSpotArp(UD60x18 t, UD60x18 effectiveDsPrice) internal pure returns (UD60x18) {
        UD60x18 pt = calcPt(effectiveDsPrice);
        return calcRt(pt, t);
    }

    /// @notice pt = 1 - effectiveDsPrice
    function calcPt(UD60x18 effectiveDsPrice) internal pure returns (UD60x18) {
        return sub(convertUd(1), effectiveDsPrice);
    }

    /// @notice ptConstFixed = f / (rate +1)^t
    /// where f = 1, and t = 1
    /// we expect that the rate is in 1e18 precision BEFORE passing it to this function
    function calcPtConstFixed(UD60x18 rate) internal pure returns (UD60x18) {
        UD60x18 ratePlusOne = add(convertUd(1), rate);
        return div(convertUd(1), ratePlusOne);
    }

    struct OptimalBorrowParams {
        MarketSnapshot market;
        uint256 maxIter;
        uint256 initialAmountOut;
        uint256 initialBorrowedAmount;
        uint256 amountSupplied;
        uint256 feeIntervalAdjustment;
        uint256 feeEpsilon;
    }

    struct OptimalBorrowResult {
        uint256 repaymentAmount;
        uint256 borrowedAmount;
        uint256 amountOut;
    }

    /**
     * @notice binary search to find the optimal borrowed amount
     * lower bound = the initial borrowed amount - (feeIntervalAdjustment * maxIter). if this doesn't satisfy the condition we revert as there's no sane lower bounds
     * upper = the initial borrowed amount.
     */
    function findOptimalBorrowedAmount(OptimalBorrowParams calldata params)
        external
        view
        returns (OptimalBorrowResult memory result)
    {
        UD60x18 amountOutUd = convertUd(params.initialAmountOut);
        UD60x18 initialBorrowedAmountUd = convertUd(params.initialBorrowedAmount);
        UD60x18 suppliedAmountUd = convertUd(params.amountSupplied);

        UD60x18 lowerBound;
        {
            UD60x18 maxLowerBound = convertUd(params.feeIntervalAdjustment * params.maxIter);
            lowerBound =
                maxLowerBound > initialBorrowedAmountUd ? convertUd(0) : sub(initialBorrowedAmountUd, maxLowerBound);
        }

        UD60x18 repaymentAmountUd = lowerBound == convertUd(0)
            ? convertUd(0)
            : convertUd(params.market.getAmountInNoConvert(convertUd(lowerBound), false));

        // we skip bounds check if the max lower bound is bigger than the initial borrowed amount
        // since it's guranteed to have enough liquidity if we never borrow
        if (repaymentAmountUd > amountOutUd && lowerBound != convertUd(0)) {
            revert IErrors.NoLowerBound();
        }

        UD60x18 upperBound = initialBorrowedAmountUd;
        UD60x18 epsilon = convertUd(params.feeEpsilon);

        for (uint256 i = 0; i < params.maxIter; ++i) {
            // we break if we have reached the desired range
            if (sub(upperBound, lowerBound) <= epsilon) {
                break;
            }

            UD60x18 midpoint = div(add(lowerBound, upperBound), convertUd(2));
            repaymentAmountUd = convertUd(params.market.getAmountInNoConvert(convertUd(midpoint), false));

            amountOutUd = add(midpoint, suppliedAmountUd);

            // we re-adjust precision here, to mitigate problems that arise when the RA decimals is less than 18(e.g USDT)
            // the problem occurs when it doesn't have enough precision to represent the actual amount of CT we received
            // from PSM.
            // example would be, we're supposed to pay 3.23 CT to the AMM, but the RA only has enough decimals
            // to represent 3.2. so we deposit 3.2 RA, then we get 3.2 CT. this is less than 3.23 CT we're supposed to pay
            // to circumvent this, we basically "round" the amountOut here on the fly to be accurate to the RA decimals.
            // this will incur a slight gas costs, but it's necessary to ensure the math is correct
            amountOutUd = convertUd(TransferHelper.fixedToTokenNativeDecimals(convertUd(amountOutUd), params.market.ra));
            amountOutUd = convertUd(TransferHelper.tokenNativeDecimalsToFixed(convertUd(amountOutUd), params.market.ra));

            if (repaymentAmountUd > amountOutUd) {
                upperBound = midpoint;
            } else {
                result.repaymentAmount = convertUd(repaymentAmountUd);
                result.borrowedAmount = convertUd(midpoint);
                result.amountOut = convertUd(amountOutUd);

                lowerBound = midpoint;
            }
        }

        // this means that there's no suitable borrowed amount that satisfies the fee constraints
        if (result.borrowedAmount == 0) {
            revert IErrors.NoConverge();
        }
    }
}
