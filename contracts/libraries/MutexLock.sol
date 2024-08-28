pragma solidity 0.8.24;

/**
 * @title NoReentrant Library Contract
 * @author Cork Team
 * @notice NoReentrant Library which implements base for Non-reentrancy with transient storage
 */
library NoReentrant {
    // The slot holding the locked state, transiently. bytes32(uint256(keccak256("Locked")) - 1)
    bytes32 private constant TRANSIENT_SLOT = 0x10bc01d611f2c803e55ff98d999836f196afae7cf91f96f3b6f511e56ba84973;

    function acquire() internal {
        assembly ("memory-safe") {
            tstore(TRANSIENT_SLOT, true)
        }
    }

    function release() internal {
        assembly ("memory-safe") {
            tstore(TRANSIENT_SLOT, false)
        }
    }

    function acquired() internal view returns (bool isAquired) {
        assembly ("memory-safe") {
            isAquired := tload(TRANSIENT_SLOT)
        }
    }
}
