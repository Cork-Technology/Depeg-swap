// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PeggedAsset,PeggedAssetLibrary} from "./PeggedAssetLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

type Id is bytes32;

/// @dev represent a token pair that does not assumes relationship between the two
/// it may be a pegged asset and a redemption asset, or ct and ds or any other pair
struct Pair {
    // pa/ct
    address pair0;
    // ra/ds
    address pair1;
}

library PairLibrary {
    using PeggedAssetLibrary for PeggedAsset;

    function toId(Pair memory key) internal pure returns (Id id) {
        bytes32 k = keccak256(abi.encode(key));

        assembly {
            id := k
        }
    }

    function toPairname(
        Pair memory key
    ) internal view returns (string memory pairname) {
        (string memory _pa, string memory _ra) = (
            IERC20Metadata(key.pair0).symbol(),
            IERC20Metadata(key.pair1).symbol()
        );

        pairname = string(abi.encodePacked(_pa, "-", _ra));
    }

    function initalize(
        address pa,
        address ra
    ) internal pure returns (Pair memory key) {
        key = Pair({pair0: pa, pair1: ra});
    }

    function peggedAsset(
        Pair memory key
    ) internal pure returns (PeggedAsset memory pa) {
        pa = PeggedAsset({_address: key.pair0});
    }

    function underlyingAsset(
        Pair memory key
    ) internal pure returns (address ra, address pa) {
        pa = key.pair0;
        ra = key.pair1;
    }

    function redemptionAsset(
        Pair memory key
    ) internal pure returns (address ra) {
        ra = key.pair1;
    }

    function isInitialized(
        Pair memory key
    ) internal pure returns (bool status) {
        status = key.pair0 != address(0) && key.pair1 != address(0);
    }
}
