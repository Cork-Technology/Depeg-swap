// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

library MutexLock {
    // The slot holding the locked state, transiently. bytes32(uint256(keccak256("Locked")) - 1)
    bytes32 internal constant IS_LOCKED_SLOT = 0x10bc01d611f2c803e55ff98d999836f196afae7cf91f96f3b6f511e56ba84973;

    function unlock() internal {
        assembly ("memory-safe") {
            // unlock
            tstore(IS_LOCKED_SLOT, false)
        }
    }

    function lock() internal {
        assembly ("memory-safe") {
            tstore(IS_LOCKED_SLOT, true)
        }
    }

    function isLocked() internal view returns (bool unlocked) {
        assembly ("memory-safe") {
            unlocked := tload(IS_LOCKED_SLOT)
        }
    }
}