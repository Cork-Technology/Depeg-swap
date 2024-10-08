pragma solidity ^0.8.24;

import {UQ112x112} from "./UQ112x112.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

    /**
     * @notice  S = (x - r * y + E) + sqrt((x - r * y)^2 + 4 * r * E * y)) / (2 * r)
     *  @param r RA exchange rate for CT:DS
     *  @param x RA reserve
     *  @param y CT reserve
     *  @param e Amount of RA user provided
     *  @return borrowed of RA user need to borrow from the AMM
     *  @return amount of DS user will receive
     */
    function getAmountOutBuyDs(uint256 r, uint256 x, uint256 y, uint256 e)
        external
        pure
        returns (uint256 borrowed, uint256 amount)
    {
        // Step 1: Calculate (x - r * y + E), with possibility that (x - r * y) is negative
        int256 term1 = int256(x) - int256(r * y / 1e18); // Convert to int256 for possible negative
        term1 = term1 + int256(e); // Add E to term1

        // Step 2: Calculate (x - r * y + E)^2
        uint256 term1Squared = uint256(term1 ** 2);

        // Step 3: Calculate 4 * r * E * y
        uint256 term2 = 4 * r * e * y / 1e18;

        // Step 4: Calculate sqrt((x - r * y + E)^2 + 4 * r * E * y)
        uint256 sqrtTerm = term1Squared + term2;
        sqrtTerm = Math.sqrt(term1Squared + term2);

        // Add term1 and sqrtTerm, then divide by (2 * r) with precision scaling with reversed equation
        // since generally x < y
        amount = sqrtTerm - SignedMath.abs(term1);

        amount = amount * 1e18 / (2 * r);

        borrowed = (r * (amount - e)) / 1e18;
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
     * @notice  e = r . s - p
     *          p = (((x*y) / (y-s)) - x)
     *
     * @param x Ra reserve
     * @param y Ct reserve
     * @param s Amount DS user want to sell and how much CT we should borrow from the AMM
     * @param r psm exchange rate for RA:CT+DS
     * @return success true if the operation is successful, false otherwise. happen generally if there's insufficient liquidity
     * @return e Amount of RA user will receive
     * @return p amount needed to repay the flash loan
     */
    function getAmountOutSellDs(uint256 x, uint256 y, uint256 s, uint256 r)
        external
        pure
        returns (bool success, uint256 e, uint256 p)
    {
        // can't do a swap if we can't borrow an equal amount of CT from the pool
        if (y <= s) {
            return (false, 0, 0);
        }

        // calculate the amount of RA user will receive
        e = r * s / 1e18;

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
