// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {UQ112x112} from "./UQ112x112.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {FixedPoint} from "Cork-Hook/lib/balancers/FixedPoint.sol";
import {SD59x18, convert, sd, add, mul, pow, sub, div, abs, unwrap} from "@prb/math/src/SD59x18.sol";
import {IMathError} from "./../interfaces/IMathError.sol";

library BuyMathBisectionSolver {
    uint256 internal constant MAX_BISECTION_ITER = 256;

    /// @notice returns the the normalized time to maturity from 1-0
    /// 1 means we're at the start of the period, 0 means we're at the end
    function computeT(SD59x18 start, SD59x18 end, SD59x18 current) internal pure returns (SD59x18) {
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

    function computeOneMinusT(SD59x18 start, SD59x18 end, SD59x18 current) internal pure returns (SD59x18) {
        return sub(convert(1), computeT(start, end, current));
    }

    /// @notice f(s) = x^1-t + y^t - (x - s + e)^1-t - (y + s)^1-t
    function f(SD59x18 x, SD59x18 y, SD59x18 e, SD59x18 s, SD59x18 _1MinusT) internal pure returns (SD59x18) {
        SD59x18 xMinSplusE = sub(x, s);
        xMinSplusE = add(xMinSplusE, e);

        SD59x18 yPlusS = add(y, s);

        {
            SD59x18 zero = convert(0);

            if (xMinSplusE < zero && yPlusS < zero) {
                revert IMathError.InvalidS();
            }
        }

        SD59x18 xPow = pow(x, _1MinusT);
        SD59x18 yPow = pow(y, _1MinusT);
        SD59x18 xMinSplusEPow = pow(xMinSplusE, _1MinusT);
        SD59x18 yPlusSPow = pow(yPlusS, _1MinusT);

        return sub(sub(add(xPow, yPow), xMinSplusEPow), yPlusSPow);
    }

    function findRoot(SD59x18 x, SD59x18 y, SD59x18 e, SD59x18 _1MinusT) internal pure returns (SD59x18) {
        SD59x18 a = sd(0);
        SD59x18 b;

        {
            SD59x18 delta = sd(1e12);
            b = sub(add(x, e), delta);
        }

        SD59x18 fA = f(x, y, e, a, _1MinusT);
        SD59x18 fB = f(x, y, e, b, _1MinusT);
        {
            if (mul(fA, fB) >= sd(0)) {
                uint256 maxAdjustments = 1000;

                SD59x18 adjustment = mul(convert(-1e4), b);
                for (uint256 i = 0; i < maxAdjustments; i++) {
                    b = sub(b, adjustment);
                    fB = f(x, y, e, b, _1MinusT);

                    if (mul(fA, fB) < sd(0)) {
                        break;
                    }
                }

                revert IMathError.NoSignChange();
            }
        }

        SD59x18 epsilon = sd(1e9);
        for (uint256 i = 0; i < MAX_BISECTION_ITER; i++) {
            SD59x18 c = div(add(a, b), convert(2));
            SD59x18 fC = f(x, y, e, c, _1MinusT);

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

        revert IMathError.NoConverge();
    }
}

/**
 * @title SwapperMathLibrary Contract
 * @author Cork Team
 * @notice SwapperMath library which implements math operations for DS swap contract
 */
library SwapperMathLibrary {
    using UQ112x112 for uint224;
    using FixedPoint for uint256;

    // Calculate price ratio of two tokens in a uniswap v2 pair, will return ratio on 18 decimals precision
    function getPriceRatio(uint256 raReserve, uint256 ctReserve)
        public
        pure
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        if (raReserve <= 0 || ctReserve <= 0) {
            revert IMathError.ZeroReserve();
        }

        raPriceRatio = ctReserve.divDown(raReserve);
        ctPriceRatio = raReserve.divDown(ctReserve);
    }

    function getAmountOutBuyDs(uint256 x, uint256 y, uint256 e, uint256 start, uint256 end, uint256 current)
        external
        pure
        returns (uint256 s)
    {
        if (x < 0 || y < 0 || e < 0) {
            revert IMathError.InvalidParam();
        }

        if (e > x && x < y) {
            revert IMathError.InsufficientLiquidity();
        }

        SD59x18 oneMinusT = BuyMathBisectionSolver.computeOneMinusT(
            convert(int256(start)), convert(int256(end)), convert(int256(current))
        );
        SD59x18 root =
            BuyMathBisectionSolver.findRoot(convert(int256(x)), convert(int256(y)), convert(int256(e)), oneMinusT);

        return uint256(convert(root));
    }

    function calculatePercentage(uint256 amount, uint256 percentage) private pure returns (uint256 result) {
        result = (((amount * 1e18) * percentage) / (100 * 1e18)) / 1e18;
    }

    /**
     * cumulatedHPA = Price_i × Volume_i × 1 - ((Discount / 86400) * (currentTime - issuanceTime))
     */
    function calculateHPAcumulated(
        uint256 effectiveDsPrice,
        uint256 amount,
        uint256 decayDiscountInDays,
        uint256 issuanceTimestamp,
        uint256 currentTime
    ) external pure returns (uint256 cumulatedHPA) {
        uint256 decay = calculateDecayDiscount(decayDiscountInDays, issuanceTimestamp, currentTime);

        cumulatedHPA = calculatePercentage(effectiveDsPrice * amount / 1e18, decay);
    }

    function calculateEffectiveDsPrice(uint256 dsAmount, uint256 raProvided)
        external
        pure
        returns (uint256 effectiveDsPrice)
    {
        effectiveDsPrice = raProvided * 1e18 / dsAmount;
    }

    function calculateVHPAcumulated(
        uint256 amount,
        uint256 decayDiscountInDays,
        uint256 issuanceTimestamp,
        uint256 currentTime
    ) external pure returns (uint256 cumulatedVHPA) {
        uint256 decay = calculateDecayDiscount(decayDiscountInDays, issuanceTimestamp, currentTime);

        cumulatedVHPA = calculatePercentage(amount, decay);
    }

    function calculateHPA(uint256 cumulatedHPA, uint256 cumulatedVHPA) external pure returns (uint256 hpa) {
        hpa = cumulatedHPA * 1e18 / cumulatedVHPA;
    }

    /**
     * decay = 1 - ((Discount / 86400) * (currentTime - issuanceTime))
     * requirements :
     * Discount * (currentTime - issuanceTime) < 100
     */
    function calculateDecayDiscount(uint256 decayDiscountInDays, uint256 issuanceTime, uint256 currentTime)
        public
        pure
        returns (uint256 decay)
    {
        if (decayDiscountInDays > type(uint112).max) {
            revert IMathError.TooBig();
        }

        uint224 discPerSec = UQ112x112.encode(uint112(decayDiscountInDays)) / 1 days;
        uint256 t = currentTime - issuanceTime;
        uint256 discount = (discPerSec * t / UQ112x112.Q112) + 1;

        // this must hold true, it doesn't make sense to have a discount above 100%
        assert(discount < 100e18);
        decay = 100e18 - discount;
    }

    function calculateRolloverSale(uint256 lvDsReserve, uint256 psmDsReserve, uint256 raProvided, uint256 hpa)
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
        uint256 totalDsReserve = lvDsReserve + psmDsReserve;

        // calculate the amount of DS user will receive
        dsReceived = raProvided * hpa / 1e18;

        // returns the RA if, the total reserve cannot cover the DS that user will receive. this Ra left must subject to the AMM rates
        raLeft = totalDsReserve > dsReceived ? 0 : ((dsReceived - totalDsReserve) * 1e18) / hpa;

        // recalculate the DS user will receive, after the RA left is deducted
        raProvided -= raLeft;
        dsReceived = raProvided * 1e18 / hpa;

        // proportionally calculate how much DS should be taken from LV and PSM
        // e.g if LV has 60% of the total reserve, then 60% of the DS should be taken from LV
        lvReserveUsed = (lvDsReserve * dsReceived * 1e18) / totalDsReserve / 1e18;
        psmReserveUsed = dsReceived - lvReserveUsed;

        // calculate the RA profit of LV and PSM
        lvProfit = (lvReserveUsed * hpa) / 1e18;
        psmProfit = (psmReserveUsed * hpa) / 1e18;

        // for rounding errors
        lvProfit = lvProfit + psmProfit + 1 == raProvided ? lvProfit + 1 : lvProfit;

        // for rounding errors
        psmReserveUsed = lvReserveUsed + psmReserveUsed + 1 == dsReceived ? psmReserveUsed + 1 : psmReserveUsed;

        assert(lvProfit + psmProfit == raProvided);
        assert(lvReserveUsed + psmReserveUsed == dsReceived);
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
}
