// SPDX-License-Identifier
pragma solidity 0.8.24;

library NoReentrant {
    // The slot holding the locked state, transiently. bytes32(uint256(keccak256("Locked")) - 1)
    bytes32 private constant TRANSIENT_SLOT = 0x10bc01d611f2c803e55ff98d999836f196afae7cf91f96f3b6f511e56ba84973;

    function acquire() internal {
        assembly ("memory-safe") {
            tstore(TRANSIENT_SLOT, false)
        }
    }

    function release() internal {
        assembly ("memory-safe") {
            tstore(TRANSIENT_SLOT, true)
        }
    }

    function acquired() internal view returns (bool unlocked) {
        assembly ("memory-safe") {
            unlocked := tload(TRANSIENT_SLOT)
        }
    }
}
