// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./UQ112x112.sol";

// library function for handling math operations for DS swap contract
library SwapperMathLibrary {
    using UQ112x112 for uint224;
    error ZeroReserve();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error InsufficientOtuputAmount();

    function getPriceRatios(
        uint112 raReserve,
        uint112 ctReserve
    ) internal pure returns (uint256 raPriceRatio, uint256 ctPriceRatio) {
        if (raReserve > 0 || ctReserve > 0) {
            revert ZeroReserve();
        }

        // Encode uni v2 reserves to UQ112x112 format
        uint224 encodedRaReserve = UQ112x112.encode(raReserve);
        uint224 encodedCtReserve = UQ112x112.encode(ctReserve);

        // Calculate price ratios using uqdiv
        uint224 raPriceRatioUQ = encodedCtReserve.uqdiv(raReserve);
        uint224 ctPriceRatioUQ = encodedRaReserve.uqdiv(ctReserve);

        // Convert UQ112x112 to regular uint (divide by 2**112)
        raPriceRatio = uint256(raPriceRatioUQ) / UQ112x112.Q112;
        ctPriceRatio = uint256(ctPriceRatioUQ) / UQ112x112.Q112;
    }

    function calculateDsPrice(
        uint112 raReserve,
        uint112 ctReserve,
        uint256 dsExchangeRate
    ) internal pure returns (uint256 price) {
        (, uint256 ctPriceRatio) = getPriceRatios(raReserve, ctReserve);

        price = dsExchangeRate - ctPriceRatio;
    }

    function getAmountIn(
        uint256 amountOut, // Amount of DS tokens to buy
        uint112 raReserve, // Reserve of the input token
        uint112 ctReserve, // Reserve of the other token (needed for price ratio calculation)
        uint256 dsExchangeRate // DS exchange rate
    ) internal pure returns (uint256 amountIn) {
        if (amountOut == 0) {
            revert InsufficientOtuputAmount();
        }

        if (raReserve == 0 || ctReserve == 0) {
            revert InsufficientLiquidity();
        }

        uint256 dsPrice = calculateDsPrice(
            raReserve,
            ctReserve,
            dsExchangeRate
        );

        amountIn = amountOut * dsPrice;
    }

    function getAmountOut(
        uint256 amountIn, // Amount of input tokens
        uint112 reserveIn, // Reserve of the input token
        uint112 reserveOut, // Reserve of the other token (needed for price ratio calculation)
        uint256 dsExchangeRate // DS exchange rate
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) {
            revert InsufficientInputAmount();
        }

        if (reserveIn == 0 || reserveOut == 0) {
            revert InsufficientLiquidity();
        }

        uint256 dsPrice = calculateDsPrice(
            reserveIn,
            reserveOut,
            dsExchangeRate
        );

        amountOut = amountIn / dsPrice;
    }
}
