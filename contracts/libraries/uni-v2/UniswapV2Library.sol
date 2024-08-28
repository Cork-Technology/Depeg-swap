pragma solidity 0.8.24;

library MinimalUniswapV2Library {
    error InvalidToken();

    // 0.3%
    uint256 public constant FEE = 997;
    // 0%
    uint256 public constant NO_FEE = 1000;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokensUnsafeWithAmount(address ra, address ct, uint256 raAmount, uint256 ctAmount)
        internal
        pure
        returns (address token0, address token1, uint256 amount0, uint256 amount1)
    {
        assert(ra != ct);
        (token0, amount0, token1, amount1) = ra < ct ? (ra, raAmount, ct, ctAmount) : (ct, ctAmount, ra, raAmount);
        assert(token0 != address(0));
    }

    function reverseSortWithAmount112(
        address token0,
        address token1,
        address ra,
        address ct,
        uint112 token0Amount,
        uint112 token1Amount
    ) internal pure returns (uint112 raAmountOut, uint112 ctAmountOut) {
        if (token0 == ra && token1 == ct) {
            raAmountOut = token0Amount;
            ctAmountOut = token1Amount;
        } else if (token0 == ct && token1 == ra) {
            raAmountOut = token1Amount;
            ctAmountOut = token0Amount;
        } else {
            revert InvalidToken();
        }
    }

    function reverseSortWithAmount224(
        address token0,
        address token1,
        address ra,
        address ct,
        uint256 token0Amount,
        uint256 token1Amount
    ) internal pure returns (uint256 raAmountOut, uint256 ctAmountOut) {
        if (token0 == ra && token1 == ct) {
            raAmountOut = token0Amount;
            ctAmountOut = token1Amount;
        } else if (token0 == ct && token1 == ra) {
            raAmountOut = token1Amount;
            ctAmountOut = token0Amount;
        } else {
            revert InvalidToken();
        }
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // WARNING: won't apply fee since we don't take fee from user right now
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * NO_FEE;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // WARNING: won't apply fee since we don't take fee from user right now
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = reserveOut * NO_FEE;
        amountIn = (numerator / denominator);
    }
}
