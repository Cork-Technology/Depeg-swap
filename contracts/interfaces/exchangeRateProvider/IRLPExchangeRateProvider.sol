// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title IRLPExchangeRateProvider Interface
 * @author Cork Team
 * @notice Interface which provides exchange rate for RLP:USR pairs
 */
interface IRLPExchangeRateProvider {
    function rate() external view returns (uint256);
}

interface IUSRPriceOracle {
    function lastPrice()
        external
        view
        returns (uint256 price, uint256 usrSupply, uint256 reserves, uint256 timestamp);
}

interface IRLPPriceOracle {
    function lastPrice() external view returns (uint256 price, uint256 timestamp);
}
