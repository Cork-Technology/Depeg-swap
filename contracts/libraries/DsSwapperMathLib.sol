pragma solidity ^0.8.24;

import {UQ112x112} from "./UQ112x112.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title SwapperMathLibrary Contract
 * @author Cork Team
 * @notice SwapperMath library which implements math operations for DS swap contract
 */
library SwapperMathLibrary {
    using UQ112x112 for uint224;
    using Math for uint256;

    /// @notice thrown when Reserve is Zero
    error ZeroReserve();

    /// @notice thrown when Input amount is not sufficient
    error InsufficientInputAmount();

    /// @notice thrown when not having sufficient Liquidity
    error InsufficientLiquidity();

    /// @notice thrown when Output amount is not sufficient
    error InsufficientOutputAmount();

    /// @notice thrown when the number is too big
    error TooBig();

    // Calculate price ratio of two tokens in a uniswap v2 pair, will return ratio on 18 decimals precision
    function getPriceRatioUniv2(uint112 raReserve, uint112 ctReserve)
        public
        pure
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        if (raReserve <= 0 || ctReserve <= 0) {
            revert ZeroReserve();
        }

        // Encode uni v2 reserves to UQ112x112 format
        uint224 encodedRaReserve = UQ112x112.encode(raReserve);
        uint224 encodedCtReserve = UQ112x112.encode(ctReserve);

        // Calculate price ratios using uqdiv
        uint224 raPriceRatioUQ = encodedCtReserve.uqdiv(raReserve);
        uint224 ctPriceRatioUQ = encodedRaReserve.uqdiv(ctReserve);

        // Convert UQ112x112 to regular uint (divide by 2**112)
        // we time by 18 to have 18 decimals precision
        raPriceRatio = (uint256(raPriceRatioUQ) * 1e18) / UQ112x112.Q112;
        ctPriceRatio = (uint256(ctPriceRatioUQ) * 1e18) / UQ112x112.Q112;
    }
    /*
     * S = (E + x - y + sqrt(E^2 + 2E(x + y) + (x - y)^2)) / 2
     *
     * Where:
     *   - s: Amount DS user received
     *   - e: RA user provided
     *   - x: RA reserve
     *   - y: CT reserve
     *   - r: RA needed to borrow from AMM
     *
     */

    function getAmountOutBuyDs(uint256 _x, uint256 _y, uint256 _e) external pure returns (uint256 r, uint256 s) {
        // first we solve the sqrt part of the equation first

        int256 x = SafeCast.toInt256(_x);
        int256 y = SafeCast.toInt256(_y);
        int256 e = SafeCast.toInt256(_e);

        // E^2
        int256 q1 = e ** 2;
        // 2E(x + y)
        int256 q2 = 2 * e * (x + y);
        // (x - y)^2
        int256 q3 = (x - y) ** 2;

        // q = sqrt(E^2 + 2E(x + y) + (x - y)^2)
        uint256 q = SignedMath.abs(q1 + q2 + q3);
        q = Math.sqrt(q);

        // then we substitue back the sqrt part to the main equation
        // S = (E + x - y + q) / 2

        // r1 = x - y (to absolute, and we reverse the equation)
        uint256 r1 = SignedMath.abs(x - y);
        // r2 = -r1 + q  = q - r1
        uint256 r2 = q - r1;
        // E + r2
        uint256 r3 = r2 + SignedMath.abs(e);

        // S = r3/2 (we multiply by 1e18 to have 18 decimals precision)
        s = (r3 * 1e18) / 2e18;

        // R = s - e (should be fine with direct typecasting)
        r = s - SignedMath.abs(e);
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
            revert TooBig();
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
     * @notice  e =  s - p
     *          p = (((x*y) / (y-s)) - x)
     *
     * @param x Ra reserve
     * @param y Ct reserve
     * @param s Amount DS user want to sell and how much CT we should borrow from the AMM
     * @return success true if the operation is successful, false otherwise. happen generally if there's insufficient liquidity
     * @return e Amount of RA user will receive
     * @return p amount needed to repay the flash loan
     */
    function getAmountOutSellDs(uint256 x, uint256 y, uint256 s)
        external
        pure
        returns (bool success, uint256 e, uint256 p)
    {
        // can't do a swap if we can't borrow an equal amount of CT from the pool
        if (x > y - s) {
            return (false, 0, 0);
        }

        // calculate the amount of RA user will receive
        e = s;

        // calculate the amount of RA user need to repay the flash loan
        p = ((x * y) / (y - s)) - x;

        // if the amount of RA user need to repay the flash loan is bigger than the amount of RA user will receive, then the operation is not successful
        if (p > e) {
            return (false, 0, 0);
        }

        success = true;
        e -= p;
    }
}
