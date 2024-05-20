// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./../Asset.sol";

struct WrappedAsset {
    address wa;
    uint256 locked;
}

library WrappedAssetLibrary {
    function initialize(
        string memory pairname
    ) internal returns (WrappedAsset memory) {
        return
            WrappedAsset({wa: address(new Asset("WA", pairname)), locked: 0});
    }

    function circulatingSupply(WrappedAsset memory self) internal view returns (uint256) {
        return Asset(self.wa).totalSupply() - self.locked;
    }

    function issueAndLock(WrappedAsset memory self, uint256 amount) internal {
        self.locked += amount;
        Asset(self.wa).mint(address(this), amount);
    }
}

// TODO : fix this, move this to a dedicated wrapper contract