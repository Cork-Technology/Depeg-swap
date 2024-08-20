// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct PeggedAsset {
    address _address;
}

library PeggedAssetLibrary {
    using PeggedAssetLibrary for PeggedAsset;
    using SafeERC20 for IERC20;

    function asErc20(PeggedAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }

    function redeemUnchecked(PeggedAsset memory self, address from, uint256 amount) internal {
        IERC20(self.asErc20()).safeTransferFrom(from, address(this), amount);
    }
}
