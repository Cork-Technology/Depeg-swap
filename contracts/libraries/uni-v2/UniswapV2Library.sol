pragma solidity ^0.8.24;

import {IUniswapV2Pair} from "../../interfaces/uniswap-v2/pair.sol";

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

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"d9becdfc30bbec341fd5a35ce5e24a7bef2f3d0bff4d43b5f8bf4e1528966ff8" // init code hash
                        )
                    )
                )
            )
        );
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }
}
