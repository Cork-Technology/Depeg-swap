// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";

/**
 * @title IExchangeRateProvider Interface
 * @author Cork Team
 * @notice Interface which provides exchange rate
 */
interface IExchangeRateProvider {
    function rate() external view returns (uint256);
    function rate(Id id) external view returns (uint256);
}
