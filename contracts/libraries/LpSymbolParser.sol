// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library LpParser {
    /// @notice parses cork AMM liquidity token symbol to get the underlying pair
    /// @dev the LP token symbol is always on the format of
    /// LP-<RA address>-<CT address> that's ASCII encoded and address is a hex string that has the standard length of 42
    function parse(string memory symbol) internal pure returns (address ra, address ct) {
        (ra, ct) = bytes(symbol).length == 88 ? _parseUnchecked(symbol) : _parseIterate(symbol);
    }

    /// @notice more efficient, since we know that the bytes number match up we can just take a chunk of the string and interpret that
    function _parseUnchecked(string memory symbol) internal pure returns (address ra, address ct) {
        string memory asciiRa = new string(42);
        string memory asciiCt = new string(42);

        // solhint-disable no-inline-assembly
        assembly ("memory-safe") {
            let symbolptr := add(symbol, 32)
            //  the RA address pointer in LP-<RA address> skipping "LP-"
            let raPtr := add(symbolptr, 3)
            //  the CT address pointer in LP-<RA address> skipping "LP-<RA address>-"
            let ctPtr := add(raPtr, 43)

            mcopy(add(asciiRa, 32), raPtr, 42)
            mcopy(add(asciiCt, 32), ctPtr, 42)
        }

        ra = Strings.parseAddress(asciiRa);
        ct = Strings.parseAddress(asciiCt);
    }

    /// @notice dynamically parses RA and CT by searching the separator(-)
    /// @dev this is needed since the hook uses toHexString not toChecksumHexString.
    /// this has the possibility where the length of the string does not conform to eip-55 length + 2(0x). see https://github.com/ethereum/ercs/blob/master/ERCS/erc-55.md
    /// in that case we must manually searches the separator. less efficient than its counterpart since we have to do O(n) operation to searche the separator
    function _parseIterate(string memory symbol) internal pure returns (address ra, address ct) {
        uint256 len = bytes(symbol).length;
        bytes memory stripped = new bytes(len - 3);

        // Strip LP- prefix
        assembly ("memory-safe") {
            // Copy length metadata
            mcopy(stripped, symbol, 32)

            // Copy content starting after "LP-" prefix
            mcopy(add(stripped, 32), add(symbol, 35), sub(len, 3))
        }

        uint256 separatorPos;
        bool foundSeparator = false;

        // Find the separator
        for (uint256 i = 0; i < stripped.length; i++) {
            if (stripped[i] == 0x2D) {
                // 0x2D is ASCII for "-"
                separatorPos = i;
                foundSeparator = true;
                break;
            }
        }

        // generally shouldn't be triggered at all. if it does, then something is horribly wrong
        assert(foundSeparator);

        bytes memory raBytes = new bytes(separatorPos);
        bytes memory ctBytes = new bytes(stripped.length - separatorPos - 1);

        assembly ("memory-safe") {
            // Copy the RA chunk
            mcopy(add(raBytes, 32), add(stripped, 32), separatorPos)
            // Copy the CT chunk (skip the separator)
            mcopy(
                add(ctBytes, 32),
                add(add(stripped, 32), add(separatorPos, 1)),
                sub(sub(mload(stripped), separatorPos), 1)
            )
        }

        ra = address(uint160(Strings.parseHexUint(string(raBytes))));
        ct = address(uint160(Strings.parseHexUint(string(ctBytes))));
    }
}
