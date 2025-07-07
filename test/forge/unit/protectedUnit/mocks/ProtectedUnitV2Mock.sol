pragma solidity ^0.8.24;

import {ProtectedUnit} from "../../../../../contracts/core/assets/ProtectedUnit.sol";

/**
 * @title Mock V2 implementation of ProtectedUnit
 * @notice Used for testing upgradeability
 */
contract ProtectedUnitV2Mock is ProtectedUnit {
    /**
     * @notice Returns the version of this implementation
     * @dev Only available in V2, used to verify upgrade was successful
     * @return The version string
     */
    function getVersion() external pure returns (string memory) {
        return "V2";
    }
}
