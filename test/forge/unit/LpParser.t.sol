// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LpParser} from "./../../../contracts/libraries/LpSymbolParser.sol";

contract LpSymbolParserTest is Test {
    function testFuzz_parse(address expectedRa, address expectedCt) external pure {
        string memory identifier =
            string.concat("LP-", Strings.toChecksumHexString(expectedRa), "-", Strings.toChecksumHexString(expectedCt));

        (address ra, address ct) = LpParser.parse(identifier);

        assertEq(ra, expectedRa);
        assertEq(ct, expectedCt);
    }
}
