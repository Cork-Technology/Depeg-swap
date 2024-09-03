pragma solidity 0.8.24;

/**
 * @dev Signature structure    
 */
struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/**
 * @title MinimalSignatureHelper Library Contract
 * @author Cork Team
 * @notice MinimalSignatureHelper Library implements signature related functions
 */
library MinimalSignatureHelper {
    /// @notice thrown when Signature length is not valid
    error InvalidSignatureLength(uint256 length);

    function split(bytes memory raw) internal pure returns (Signature memory sig) {
        if (raw.length != 65) {
            revert InvalidSignatureLength(raw.length);
        }

        (uint8 v, bytes32 r, bytes32 s) = splitUnchecked(raw);

        sig = Signature({v: v, r: r, s: s});
    }

    function splitUnchecked(bytes memory sig) private pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
