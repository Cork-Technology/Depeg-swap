pragma solidity 0.8.24;

import {IUniswapV2Factory} from "../interfaces/uniswap-v2/factory.sol";
import {MinimalUniswapV2Library} from "../libraries/uni-v2/UniswapV2Library.sol"; // Assumes you have this library from the router contract
import {IUniswapV2Router02} from "../interfaces/uniswap-v2/RouterV2.sol";
/**
 * @title PriceFeedReader Contract
 * @author Cork Team
 * @notice PriceFeedReader contract for reading price details of assets
 */

contract UniswapPriceReader {
    address public factory;
    address public router;

    constructor(address _factory, address _router) {
        factory = _factory;
        router = _router;
    }

    // Get the price of Destination Token in terms of source token
    function getTokenPrice(address destToken, address sourceToken) public view returns (uint256 price) {
        address pair = IUniswapV2Factory(factory).getPair(destToken, sourceToken);
        require(pair != address(0), "Pair doesn't exist");

        address[] memory path = new address[](2);
        path[0] = destToken;
        path[1] = sourceToken;
        price = IUniswapV2Router02(router).getAmountsOut(1e18, path)[1];
    }
}
