// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {convert, intoUD60x18} from "@prb/math/src/SD59x18.sol";
import {UD60x18, convert, ud, add, mul, pow, sub, div, unwrap} from "@prb/math/src/UD60x18.sol";
import {IErrors} from "./../interfaces/IErrors.sol";
import {BuyMathBisectionSolver} from "./DsSwapperMathLib.sol";
import {TransferHelper} from "./TransferHelper.sol";

library ProtectedUnitMath {
    function previewMint(uint256 amount, uint256 paReserve, uint256 dsReserve, uint256 totalLiquidity)
        internal
        pure
        returns (uint256 dsAmount, uint256 paAmount)
    {
        if (totalLiquidity == 0) {
            return (amount, amount);
        }

        dsAmount = unwrap(mul(ud(amount), div(ud(dsReserve), ud(totalLiquidity))));
        paAmount = unwrap(mul(ud(amount), div(ud(paReserve), ud(totalLiquidity))));
    }

    function normalizeDecimals(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter)
        internal
        pure
        returns (uint256)
    {
        return TransferHelper.normalizeDecimals(amount, decimalsBefore, decimalsAfter);
    }

    function withdraw(
        uint256 reservePa,
        uint256 reserveDs,
        uint256 reserveRa,
        uint256 totalLiquidity,
        uint256 liquidityAmount
    ) internal pure returns (uint256 amountPa, uint256 amountDs, uint256 amountRa) {
        if (liquidityAmount <= 0) {
            revert IErrors.InvalidAmount();
        }

        if (totalLiquidity <= 0) {
            revert IErrors.NotEnoughLiquidity();
        }

        // Calculate the proportion of reserves to return based on the liquidity removed
        amountPa = unwrap(div(mul(ud(liquidityAmount), ud(reservePa)), ud(totalLiquidity)));

        amountDs = unwrap(div(mul(ud(liquidityAmount), ud(reserveDs)), ud(totalLiquidity)));

        amountRa = unwrap(div(mul(ud(liquidityAmount), ud(reserveRa)), ud(totalLiquidity)));
    }
}
