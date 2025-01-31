pragma solidity ^0.8.24;

import {convert, intoUD60x18} from "@prb/math/src/SD59x18.sol";
import {UD60x18, convert, ud, add, mul, pow, sub, div, unwrap} from "@prb/math/src/UD60x18.sol";
import {IErrors} from "./../interfaces/IErrors.sol";
import {BuyMathBisectionSolver} from "./DsSwapperMathLib.sol";
import {TransferHelper} from "./TransferHelper.sol";

library ProtectedUnitMath {
    // caller of this contract must ensure the both amount is already proportional in amount!
    function mint(uint256 reservePa, uint256 totalLiquidity, uint256 amountPa, uint256 amountDs)
        internal
        pure
        returns (uint256 liquidityMinted)
    {
        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        // we mint 1:1 if total liquidity is 0, also enforce that the amount must be the same
        if (totalLiquidity == 0) {
            if (amountPa != amountDs) {
                revert IErrors.InvalidAmount();
            }

            liquidityMinted = amountPa;
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = unwrap(div(mul((ud(amountPa)), ud(totalLiquidity)), ud(reservePa)));
        }
    }

    function getProportionalAmount(uint256 amount0, uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (uint256 amount1)
    {
        return unwrap(div(mul(ud(amount0), ud(reserve1)), ud(reserve0)));
    }

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
