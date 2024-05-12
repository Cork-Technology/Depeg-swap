// SPDX-License-Identifier: MIT
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

    function issueAndLock(WrappedAsset memory self, uint256 amount) internal {
        Asset(self.wa).mint(address(this), amount);
        self.locked += amount;
    }
}
