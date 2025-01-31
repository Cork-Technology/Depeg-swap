// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {IErrors} from "./../interfaces/IErrors.sol";
import {IExchangeRateProvider} from "./../interfaces/IExchangeRateProvider.sol";

/**
 * @title ExchangeRateProvider Contract
 * @author Cork Team
 * @notice Contract for managing exchange rate
 */
contract ExchangeRateProvider is IErrors, IExchangeRateProvider {
    using PairLibrary for Pair;

    address internal CONFIG;

    mapping(Id => uint256) internal exchangeRate;

    /**
     * @dev checks if caller is config contract or not
     */
    function onlyConfig() internal {
        if (msg.sender != CONFIG) {
            revert IErrors.OnlyConfigAllowed();
        }
    }

    constructor(address _config) {
        if (_config == address(0)) {
            revert IErrors.ZeroAddress();
        }
        CONFIG = _config;
    }

    function rate() external view returns (uint256) {
        return 0; // For future use
    }

    function rate(Id id) external view returns (uint256) {
        return exchangeRate[id];
    }

    function setRate(Id id, uint256 _rate) external {
        onlyConfig();
        exchangeRate[id] = _rate;
    }
}