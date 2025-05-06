// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library LpParser {
    /// @notice parses cork AMM liquidity token symbol to get the underlying pair
    /// @dev the LP token symbol is always on the format of
    /// LP-<RA address>-<CT address> that's ASCII encoded and address is a hex string that has the standard length of 42
    function parse(string memory symbol) internal pure returns (address ra, address ct) {
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
}
