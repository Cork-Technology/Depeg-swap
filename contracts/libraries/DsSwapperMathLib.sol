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
    function getAmountOutDs(int256 x, int256 y, int256 e) external pure returns (uint256 r, uint256 s) {
        // first we solve the sqrt part of the equation first

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
}
