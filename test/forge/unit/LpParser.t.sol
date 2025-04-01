// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LpParser} from "./../../../contracts/libraries/LpSymbolParser.sol";

contract LpSymbolParserTest is Test {
    function testFuzz_parse(address expectedRa, address expectedCt) external {
        string memory identifier =
            string.concat("LP-", Strings.toHexString(expectedRa), "-", Strings.toHexString(expectedCt));
        vm.resetGasMetering();

        (address ra, address ct) = LpParser.parse(identifier);

        assertEq(ra, expectedRa);
        assertEq(ct, expectedCt);
    }

    function testFuzz_parseWeirdAddress(address expectedRa, address expectedCt) external {
        vm.assume(expectedRa < address(1000) && expectedCt < address(1000));

        string memory identifier =
            string.concat("LP-", Strings.toHexString(expectedRa), "-", Strings.toHexString(expectedCt));

        vm.resetGasMetering();
        (address ra, address ct) = LpParser.parse(identifier);

        assertEq(ra, expectedRa);
        assertEq(ct, expectedCt);
    }
}
