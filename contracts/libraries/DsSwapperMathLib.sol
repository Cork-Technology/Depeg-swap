pragma solidity 0.8.24;

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

    function calculateDsPrice(uint112 raReserve, uint112 ctReserve, uint256 dsExchangeRate)
        public
        pure
        returns (uint256 price)
    {
        (, uint256 ctPriceRatio) = getPriceRatioUniv2(raReserve, ctReserve);

        price = dsExchangeRate - ctPriceRatio;
    }

    function getAmountIn(
        uint256 amountOut, // Amount of DS tokens to buy
        uint112 raReserve, // Reserve of the input token
        uint112 ctReserve, // Reserve of the other token (needed for price ratio calculation)
        uint256 dsExchangeRate // DS exchange rate
    ) external pure returns (uint256 amountIn) {
        if (amountOut == 0) {
            revert InsufficientOutputAmount();
        }

        if (raReserve == 0 || ctReserve == 0) {
            revert InsufficientLiquidity();
        }

        uint256 dsPrice = calculateDsPrice(raReserve, ctReserve, dsExchangeRate);

        amountIn = (amountOut * dsPrice) / 1e18;
    }

    function getAmountOut(
        uint256 amountIn, // Amount of input tokens
        uint112 reserveIn, // Reserve of the input token
        uint112 reserveOut, // Reserve of the other token (needed for price ratio calculation)
        uint256 dsExchangeRate // DS exchange rate
    ) external pure returns (uint256 amountOut) {
        if (amountIn == 0) {
            revert InsufficientInputAmount();
        }

        if (reserveIn == 0 || reserveOut == 0) {
            revert InsufficientLiquidity();
        }

        uint256 dsPrice = calculateDsPrice(reserveIn, reserveOut, dsExchangeRate);

        amountOut = amountIn / dsPrice;
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
    function getAmountOutDs(int256 raReserve, int256 ctReserve, int256 raProvided)
        external
        pure
        returns (uint256 raBorrowed, uint256 dsReceived)
    {
        // first we solve the sqrt part of the equation first

        // E^2
        int256 q1 = raProvided ** 2;
        // 2E(x + y)
        int256 q2 = 2 * raProvided * (raReserve + ctReserve);
        // (x - y)^2
        int256 q3 = (raReserve - ctReserve) ** 2;

        // q = sqrt(E^2 + 2E(x + y) + (x - y)^2)
        uint256 q = SignedMath.abs(q1 + q2 + q3);
        q = Math.sqrt(q);

        // then we substitue back the sqrt part to the main equation
        // S = (E + x - y + q) / 2

        // r1 = x - y (to absolute, and we reverse the equation)
        uint256 r1 = SignedMath.abs(raReserve - ctReserve);
        // r2 = -r1 + q  = q - r1
        uint256 r2 = q - r1;
        // E + r2
        uint256 r3 = r2 + SignedMath.abs(raProvided);

        // S = r3/2 (we multiply by 1e18 to have 18 decimals precision)
        dsReceived = (r3 * 1e18) / 2e18;

        // R = s - e (should be fine with direct typecasting)
        raBorrowed = dsReceived - SignedMath.abs(raProvided);
    }

    function calculatePrecentage(uint256 amount, uint256 precentage) private pure returns (uint256 result) {
        result = (((amount * 1e18) * precentage) / (100 * 1e18)) / 1e18;
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

        cumulatedHPA = calculatePrecentage(effectiveDsPrice * amount / 1e18, decay);
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

        cumulatedVHPA = calculatePrecentage(amount, decay);
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
        lvProfit = lvProfit  + psmProfit + 1 == raProvided ? lvProfit + 1 : lvProfit;
        
        // for rounding errors
        psmReserveUsed = lvReserveUsed + psmReserveUsed + 1 == dsReceived ? psmReserveUsed + 1 : psmReserveUsed;

        assert(lvProfit + psmProfit == raProvided);
        assert(lvReserveUsed + psmReserveUsed == dsReceived);
    }
}
