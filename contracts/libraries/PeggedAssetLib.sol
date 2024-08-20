// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct PeggedAsset {
    address _address;
}

library PeggedAssetLibrary {
    using PeggedAssetLibrary for PeggedAsset;

    function asErc20(PeggedAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }

    function redeemUnchecked(PeggedAsset memory self, address from, uint256 amount) internal {
        self.asErc20().transferFrom(from, address(this), amount);
    }
}
