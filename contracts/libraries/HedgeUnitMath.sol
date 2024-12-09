pragma solidity ^0.8.24;

import {UD60x18, convert, ud, add, mul, pow, sub, div, unwrap, intoSD59x18, sqrt} from "@prb/math/src/UD60x18.sol";
import "./../interfaces/IErrors.sol";

library LiquidityMath {
    // Adding Liquidity (Pure Function)
    // caller of this contract must ensure the both amount is already proportional in amount!
    function addLiquidity(
        uint256 reserve0, // Current reserve of RA (target token)
        uint256 reserve1, // Current reserve of CT (yield-bearing token)
        uint256 totalLiquidity, // Total current liquidity (LP token supply)
        uint256 amount0, // Amount of RA to add
        uint256 amount1 // Amount of CT to add
    )
        internal
        pure
        returns (
            uint256 newReserve0, // Updated reserve of RA
            uint256 newReserve1, // Updated reserve of CT
            uint256 liquidityMinted // Amount of liquidity tokens minted
        )
    {
        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        // we mint 1:1 if total liquidity is 0, also enforce that the amount must be the same
        if (totalLiquidity == 0) {
            assert(amount0 == amount1);

            liquidityMinted = amount0;
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = unwrap(div(mul((ud(amount0)), ud(totalLiquidity)), ud(reserve0)));
        }

        // Update reserves
        newReserve0 = unwrap(add(ud(reserve0), ud(amount0)));
        newReserve1 = unwrap(add(ud(reserve1), ud(amount1)));

        return (newReserve0, newReserve1, liquidityMinted);
    }

    function getProportionalAmount(uint256 amount0, uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (uint256 amount1)
    {
        return unwrap(div(mul(ud(amount0), ud(reserve1)), ud(reserve0)));
    }

    // uni v2 style proportional add liquidity
    function inferOptimalAmount(
        uint256 reserve0,
        uint256 reserve1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = getProportionalAmount(amount0Desired, reserve0, reserve1);

            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) {
                    revert IErrors.Insufficient1Amount();
                }

                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = getProportionalAmount(amount1Desired, reserve1, reserve0);
                if (amount0Optimal < amount0Min || amount0Optimal > amount0Desired) {
                    revert IErrors.Insufficient0Amount();
                }
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }

    // Removing Liquidity (Pure Function)
    function removeLiquidity(
        uint256 reserve0, // Current reserve of RA (target token)
        uint256 reserve1, // Current reserve of CT (yield-bearing token)
        uint256 totalLiquidity, // Total current liquidity (LP token supply)
        uint256 liquidityAmount // Amount of liquidity tokens being removed
    )
        internal
        pure
        returns (
            uint256 amount0, // Amount of RA returned to the LP
            uint256 amount1, // Amount of CT returned to the LP
            uint256 newReserve0, // Updated reserve of RA
            uint256 newReserve1 // Updated reserve of CT
        )
    {
        if (liquidityAmount <= 0) {
            revert IErrors.InvalidAmount();
        }

        if (totalLiquidity <= 0) {
            revert IErrors.NotEnoughLiquidity();
        }

        // Calculate the proportion of reserves to return based on the liquidity removed
        amount0 = unwrap(div(mul(ud(liquidityAmount), ud(reserve0)), ud(totalLiquidity)));

        amount1 = unwrap(div(mul(ud(liquidityAmount), ud(reserve1)), ud(totalLiquidity)));

        // Update reserves after removing liquidity
        newReserve0 = unwrap(sub(ud(reserve0), ud(amount0)));

        newReserve1 = unwrap(sub(ud(reserve1), ud(amount1)));

        return (amount0, amount1, newReserve0, newReserve1);
    }
}
