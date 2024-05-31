// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Asset.sol";

struct LvAsset {
    address _address;
}

library LvAssetLibrary {
    using LvAssetLibrary for LvAsset;

    function asErc20(LvAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }

    function depositUnchecked(
        LvAsset memory self,
        address from,
        uint256 amount
    ) internal {
        self.asErc20().transferFrom(from, address(this), amount);
    }

    function totalIssued(
        LvAsset memory self
    ) internal view returns (uint256 total) {
        total = IERC20(self._address).totalSupply();
    }

    function issue(LvAsset memory self, address to, uint256 amount) internal {
        Asset(self._address).mint(to, amount);
    }
}
