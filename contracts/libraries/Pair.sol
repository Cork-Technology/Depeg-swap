// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PeggedAsset, PeggedAssetLibrary} from "./PeggedAssetLib.sol";

type Id is bytes32;

/**
 * @dev represent a RA/PA pair
 */
struct Pair {
    // pa/ct
    address pa;
    // ra/ds
    address ra;
    // expiry interval
    uint256 expiryInterval;
}

/**
 * @title PairLibrary Contract
 * @author Cork Team
 * @notice Pair Library which implements functions for handling Pair operations
 */
library PairLibrary {
    using PeggedAssetLibrary for PeggedAsset;

    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    error InvalidAddress();

    function toId(Pair memory key) internal pure returns (Id id) {
        id = Id.wrap(keccak256(abi.encode(key)));
    }

    function initalize(address pa, address ra, uint256 expiry) internal pure returns (Pair memory key) {
        if (pa == address(0) || ra == address(0)) {
            revert ZeroAddress();
        }
        if(pa == ra) {
            revert InvalidAddress();
        }
        key = Pair(pa, ra, expiry);
    }

    function peggedAsset(Pair memory key) internal pure returns (PeggedAsset memory pa) {
        pa = PeggedAsset({_address: key.pa});
    }

    function underlyingAsset(Pair memory key) internal pure returns (address ra, address pa) {
        pa = key.pa;
        ra = key.ra;
    }

    function redemptionAsset(Pair memory key) internal pure returns (address ra) {
        ra = key.ra;
    }

    function isInitialized(Pair memory key) internal pure returns (bool status) {
        status = key.pa != address(0) && key.ra != address(0);
    }
}
