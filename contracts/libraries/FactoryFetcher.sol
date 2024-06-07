// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../WrappedAsset.sol";
import "../AssetFactory.sol";

library Fetcher {
    function getDeployedWrappedAssets(
        uint8 page,
        uint8 limit,
        uint256 idx,
        mapping(uint256 => WrappedAssets) storage wrappedAssets
    ) external view returns (address[] memory ra, address[] memory wa) {
        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);
        uint256 arrLen = end - start;

        if (end > idx) {
            end = idx;
        }

        if (start > idx) {
            return (ra, wa);
        }

        ra = new address[](arrLen);
        wa = new address[](arrLen);

        for (uint256 i = start; i < end; i++) {
            WrappedAssets storage asset = wrappedAssets[i];
            uint8 _idx = uint8(i - start);

            ra[_idx] = asset.ra;
            wa[_idx] = asset.wa;
        }
    }
}
