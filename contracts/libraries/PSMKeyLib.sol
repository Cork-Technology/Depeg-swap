// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

type PsmId is bytes32;

struct PsmKey {
    address peggedAsset;
    address redemptionAsset;
}

library PsmKeyLibrary {
    function toId(PsmKey memory key) internal pure returns (PsmId id) {
        bytes32 k = keccak256(abi.encode(key));

        assembly {
            id := k
        }
    }

    function isInitialized(
        PsmKey memory key
    ) internal pure returns (bool status) {
        status =
            key.peggedAsset != address(0) &&
            key.redemptionAsset != address(0);
    }
}
