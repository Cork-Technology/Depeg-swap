pragma solidity 0.8.24;

import {UQ112x112} from "./UQ112x112.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// library function for handling math operations for DS swap contract
library SwapperMathLibrary {
    using UQ112x112 for uint224;

    error ZeroReserve();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error InsufficientOtuputAmount();

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
    function getAmountOutDs(int256 raReserve, int256 ctReserve, int256 raProvided) external pure returns (uint256 raBorrowed, uint256 dsReceived) {
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

    function calculatePrecentage(uint256 amount, uint256 precentage) private pure returns(uint256 result){
        result = (((amount * 1e18) * precentage) / (100 * 1e18)) / 1e18;
    }

    /**
     * cumulatedHPA = Price_i × Volume_i × 1 - ((Discount / 86400) * (currentTime - issuanceTime))
     */
    function calculateHPAcumulated(uint256 effectiveDsPrice, uint256 amount, uint256 decayDiscountInDays, uint256 issuanceTimestamp, uint256 currentTime) external pure returns(uint256 cumulatedHPA){
        uint256 decay = calculateDecayDiscount(decayDiscountInDays, issuanceTimestamp, currentTime);

        cumulatedHPA = calculatePrecentage(effectiveDsPrice * amount / 1e18, decay) ;
    }

    function calculateEffectiveDsPrice(uint256 dsAmount, uint256 raProvided) external pure returns(uint256 effectiveDsPrice){
        effectiveDsPrice = raProvided * 1e18 / dsAmount;
    }

    function calculateVHPAcumulated(uint256 amount, uint256 decayDiscountInDays, uint256 issuanceTimestamp, uint256 currentTime) external pure returns (uint256 cumulatedVHPA) {
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
    function calculateDecayDiscount(uint256 decayDiscountInDays, uint256 issuanceTime, uint256 currentTime) public pure returns (uint256 decay) {
        uint256 discPerSec = decayDiscountInDays / 1 days;
        uint256 t = currentTime - issuanceTime;
        uint256 discount = discPerSec * t;

        // this must hold true, it doesn't make sense to have a discount above 100%
        assert(discount < 100e18);
        decay = 100e18 - discount;
    }
}
