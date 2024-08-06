pragma solidity ^0.8.0;

library MinimalUniswapV2Library {
    // 0.3%
    uint public constant FEE = 997;
    // 0%
    uint public constant NO_FEE = 1000;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokensUnsafeWithAmount(
        address ra,
        address ct,
        uint256 raAmount,
        uint256 ctAmount
    )
        internal
        pure
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        assert(ra != ct);
        (token0, amount0, token1, amount1) = ra < ct
            ? (ra, raAmount, ct, ctAmount)
            : (ct, ctAmount, ra, raAmount);
        assert(token0 != address(0));
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // WARNING: won't apply fee since we don't take fee from user right now
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint amountInWithFee = amountIn * NO_FEE;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // WARNING: won't apply fee since we don't take fee from user right now
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = reserveOut * NO_FEE;
        amountIn = (numerator / denominator);
    }
}
