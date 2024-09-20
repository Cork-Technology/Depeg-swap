pragma solidity 0.8.24;

import {IUniswapV2Pair} from "../interfaces/uniswap-v2/pair.sol";
import {IUniswapV2Factory} from "../interfaces/uniswap-v2/factory.sol";
import {MinimalUniswapV2Library} from "../libraries/uni-v2/UniswapV2Library.sol"; // Assumes you have this library from the router contract

/**
 * @title PriceFeedReader Contract
 * @author Cork Team
 * @notice PriceFeedReader contract for reading price details of assets
 */
contract UniswapPriceReader {
    address public factory;

    constructor(address _factory) {
        factory = _factory;
    }

    // Get the price of tokenA in terms of tokenB
    function getTokenPrice(address tokenA, address tokenB) public view returns (uint256 price) {
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Pair doesn't exist");

        (uint256 reserveA, uint256 reserveB) = MinimalUniswapV2Library.getReserves(factory, tokenA, tokenB);

        // If tokenA < tokenB in sort order, price is reserveB / reserveA
        // If tokenB < tokenA in sort order, price is reserveA / reserveB
        price = MinimalUniswapV2Library.quote(1e18, reserveA, reserveB); // Assuming token has 18 decimals
    }

    // Get both reserve values of a pair
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
        (reserveA, reserveB) = MinimalUniswapV2Library.getReserves(factory, tokenA, tokenB);
    }
}
