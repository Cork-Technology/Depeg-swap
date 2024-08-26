// taken directly from forked repo
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
}
