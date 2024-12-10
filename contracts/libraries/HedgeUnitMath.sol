pragma solidity ^0.8.24;

import {UD60x18, convert, ud, add, mul, pow, sub, div, unwrap, intoSD59x18, sqrt} from "@prb/math/src/UD60x18.sol";
import "./../interfaces/IHedgeUnit.sol";

library HedgeUnitLiquidityMath {
    // Adding Liquidity (Pure Function)
    // caller of this contract must ensure the both amount is already proportional in amount!
    function addLiquidity(
        uint256 reservePa,
        uint256 reserveDs,
        uint256 totalLiquidity,
        uint256 amountPa,
        uint256 amountDs
    )
        internal
        pure
        returns (
            uint256 newReservePa,
            uint256 newReserveDs,
            uint256 liquidityMinted // Amount of liquidity tokens minted
        )
    {
        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        // we mint 1:1 if total liquidity is 0, also enforce that the amount must be the same
        if (totalLiquidity == 0) {
            if (amountPa != amountDs) {
                revert IHedgeUnit.InvalidAmount();
            }

            liquidityMinted = amountPa;
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = unwrap(div(mul((ud(amountPa)), ud(totalLiquidity)), ud(reservePa)));
        }

        // Update reserves
        newReservePa = unwrap(add(ud(reservePa), ud(amountPa)));
        newReserveDs = unwrap(add(ud(reserveDs), ud(amountDs)));

        return (newReservePa, newReserveDs, liquidityMinted);
    }

    function getProportionalAmount(uint256 amountPa, uint256 reservePa, uint256 reserveDs)
        internal
        pure
        returns (uint256 amountDs)
    {
        return unwrap(div(mul(ud(amountPa), ud(reserveDs)), ud(reservePa)));
    }

    // uni v2 style proportional add liquidity
    function inferOptimalAmount(
        uint256 reservePa,
        uint256 reserveDs,
        uint256 amountPaDesired,
        uint256 amountDsDesired,
        uint256 amountPaMin,
        uint256 amountDsMin
    ) internal pure returns (uint256 amountPa, uint256 amountDs) {
        if (reservePa == 0 && reserveDs == 0) {
            (amountPa, amountDs) = (amountPaDesired, amountDsDesired);
        } else {
            uint256 amountDsOptimal = getProportionalAmount(amountPaDesired, reservePa, reserveDs);

            if (amountDsOptimal <= amountDsDesired) {
                if (amountDsOptimal < amountDsMin) {
                    revert IHedgeUnit.InsufficientDsAmount();
                }

                (amountPa, amountDs) = (amountPaDesired, amountDsOptimal);
            } else {
                uint256 amountPaOptimal = getProportionalAmount(amountDsDesired, reserveDs, reservePa);
                if (amountPaOptimal < amountPaMin || amountPaOptimal > amountPaDesired) {
                    revert IHedgeUnit.InsufficientPaAmount();
                }
                (amountPa, amountDs) = (amountPaOptimal, amountDsDesired);
            }
        }
    }

    // Removing Liquidity (Pure Function)
    function removeLiquidity(
        uint256 reservePa, // Current reserve of RA (target token)
        uint256 reserveDs, // Current reserve of CT (yield-bearing token)
        uint256 totalLiquidity, // Total current liquidity (LP token supply)
        uint256 liquidityAmount // Amount of liquidity tokens being removed
    )
        internal
        pure
        returns (
            uint256 amountPa, // Amount of RA returned to the LP
            uint256 amountDs, // Amount of CT returned to the LP
            uint256 newReservePa, // Updated reserve of RA
            uint256 newReserveDs // Updated reserve of CT
        )
    {
        if (liquidityAmount <= 0) {
            revert IHedgeUnit.InvalidAmount();
        }

        if (totalLiquidity <= 0) {
            revert IHedgeUnit.NotEnoughLiquidity();
        }

        // Calculate the proportion of reserves to return based on the liquidity removed
        amountPa = unwrap(div(mul(ud(liquidityAmount), ud(reservePa)), ud(totalLiquidity)));

        amountDs = unwrap(div(mul(ud(liquidityAmount), ud(reserveDs)), ud(totalLiquidity)));

        // Update reserves after removing liquidity
        newReservePa = unwrap(sub(ud(reservePa), ud(amountPa)));

        newReserveDs = unwrap(sub(ud(reserveDs), ud(amountDs)));

        return (amountPa, amountDs, newReservePa, newReserveDs);
    }
}
