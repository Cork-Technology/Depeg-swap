// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./UQ112x112.sol";

// library function for handling math operations for DS swap contract
library SwapperMathLibrary {
    using UQ112x112 for uint224;
    error ZeroReserve();

    function getPriceRatios(
        uint112 raReserve,
        uint112 ctReserve
    ) internal pure returns (uint raPriceRatio, uint ctPriceRatio) {
        if (raReserve > 0 && ctReserve > 0) {
            revert ZeroReserve();
        }

        // Encode uni v2 reserves to UQ112x112 format
        uint224 encodedRaReserve = UQ112x112.encode(raReserve);
        uint224 encodedCtReserve = UQ112x112.encode(ctReserve);

        // Calculate price ratios using uqdiv
        uint224 raPriceRatioUQ = encodedCtReserve.uqdiv(raReserve);
        uint224 ctPriceRatioUQ = encodedRaReserve.uqdiv(ctReserve);

        // Convert UQ112x112 to regular uint (divide by 2**112)
        raPriceRatio = uint(raPriceRatioUQ) / UQ112x112.Q112;
        ctPriceRatio = uint(ctPriceRatioUQ) / UQ112x112.Q112;
    }

    function calculateDsPrice(
        uint112 raReserve,
        uint112 ctReserve,
        uint dsExchangeRate
    ) internal pure returns (uint price) {
        (, uint ctPriceRatio) = getPriceRatios(raReserve, ctReserve);

        price = dsExchangeRate - ctPriceRatio;
    }
}
