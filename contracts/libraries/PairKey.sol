// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PeggedAssetLib.sol";
import "./RedemptionAssetLib.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

type PsmId is bytes32;

struct PairKey {
    address _peggedAsset;
    address _redemptionAsset;
}

library PairKeyLibrary {
    using PeggedAssetLibrary for PeggedAsset;

    function toId(PairKey memory key) internal pure returns (PsmId id) {
        bytes32 k = keccak256(abi.encode(key));

        assembly {
            id := k
        }
    }

    function toPairname(
        PairKey memory key
    ) internal view returns (string memory pairname) {
        (string memory _pa, string memory _ra) = (
            IERC20Metadata(key._peggedAsset).symbol(),
            IERC20Metadata(key._redemptionAsset).symbol()
        );

        pairname = string(abi.encodePacked(_pa, "-", _ra));
    }

    function initalize(
        address pa,
        address ra
    ) internal pure returns (PairKey memory key) {
        key = PairKey({_peggedAsset: pa, _redemptionAsset: ra});
    }

    function peggedAsset(
        PairKey memory key
    ) internal pure returns (PeggedAsset memory pa) {
        pa = PeggedAsset({_address: key._peggedAsset});
    }

    function redemptionAsset(
        PairKey memory key
    ) internal pure returns (RedemptionAsset memory ra) {
        ra = RedemptionAsset({_address: key._redemptionAsset});
    }

    function isInitialized(
        PairKey memory key
    ) internal pure returns (bool status) {
        status =
            key._peggedAsset != address(0) &&
            key._redemptionAsset != address(0);
    }
}
