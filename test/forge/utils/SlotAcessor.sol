// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Helper contract to access transient storage slots
contract SlotAccessor {
    function getSlotValue(bytes32 slot) external view returns (uint256) {
        uint256 value;
        assembly {
            value := tload(slot)
        }
        return value;
    }

    function setSlotValue(bytes32 slot, uint256 value) external {
        assembly {
            tstore(slot, value)
        }
    }
}
