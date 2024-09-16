pragma solidity ^0.8.24;

import {PeggedAsset, PeggedAssetLibrary} from "./PeggedAssetLib.sol";

type Id is bytes32;

/**
 * @dev represent a token pair that does not assumes relationship between the two
 * @dev it may be a pegged asset and a redemption asset, or ct and ds or any other pair
 */
struct Pair {
    // pa/ct
    address pair0;
    // ra/ds
    address pair1;
}

/**
 * @title PairLibrary Contract
 * @author Cork Team
 * @notice Pair Library which implements functions for handling Pair operations
 */
library PairLibrary {
    using PeggedAssetLibrary for PeggedAsset;

    function toId(Pair memory key) internal pure returns (Id id) {
        id = Id.wrap(keccak256(abi.encode(key)));
    }

    function initalize(address pa, address ra) internal pure returns (Pair memory key) {
        key = Pair({pair0: pa, pair1: ra});
    }

    function peggedAsset(Pair memory key) internal pure returns (PeggedAsset memory pa) {
        pa = PeggedAsset({_address: key.pair0});
    }

    function underlyingAsset(Pair memory key) internal pure returns (address ra, address pa) {
        pa = key.pair0;
        ra = key.pair1;
    }

    function redemptionAsset(Pair memory key) internal pure returns (address ra) {
        ra = key.pair1;
    }

    function isInitialized(Pair memory key) internal pure returns (bool status) {
        status = key.pair0 != address(0) && key.pair1 != address(0);
    }
}
