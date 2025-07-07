// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProtectedUnitFactory} from "contracts/core/assets/ProtectedUnitFactory.sol";

/**
 * @title Mock V2 implementation of ProtectedUnitFactory
 * @notice Used for testing upgradeability
 */
contract ProtectedUnitFactoryV2Mock is ProtectedUnitFactory {
    /**
     * @notice Returns the version of this implementation
     * @dev Only available in V2, used to verify upgrade was successful
     * @return The version string
     */
    function getVersion() external pure returns (string memory) {
        return "V2";
    }
}
