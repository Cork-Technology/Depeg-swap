// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "./../../interfaces/IAggregatorV3.sol";
import {ModuleCore} from "./../ModuleCore.sol";
import {IErrors} from "./../../interfaces/IErrors.sol";

/**
 * @title CT Oracle contract
 * @author Cork Team
 * @notice CT Oracle contract for providing CT price
 */
abstract contract BaseOracle is AggregatorV3Interface, IErrors {
    address public moduleCore;

    address public ct;

    constructor(address _moduleCore, address _ct) {
        moduleCore = _moduleCore;
        ct = _ct;
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    function description() external view returns (string memory) {
        // TODO
    }

    function version() external view returns (uint256) {
        return 0;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        revert NotSupported();
    }

    // to be inherited and defined by child contracts
    function _prepareRoundData() internal view virtual returns (uint256 backedRa, uint256 backedPa);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint256 backedRa, uint256 backedPa) = _prepareRoundData();
        // TODO do something, consult with Heri
    }
}
