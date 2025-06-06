// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Asset} from "../core/assets/Asset.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev LvAsset structure for Liquidity Vault Assets
 */
struct LvAsset {
    address _address;
    uint256 locked;
}

/**
 * @title LvAssetLibrary Contract
 * @author Cork Team
 * @notice LvAsset Library which implements features related to Lv(liquidity vault) Asset contract
 */
library LvAssetLibrary {
    using LvAssetLibrary for LvAsset;
    using SafeERC20 for IERC20;

    function initialize(address _address) internal pure returns (LvAsset memory) {
        return LvAsset(_address, 0);
    }

    function asErc20(LvAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }

    function isInitialized(LvAsset memory self) internal pure returns (bool) {
        return self._address != address(0);
    }

    function totalIssued(LvAsset memory self) internal view returns (uint256 total) {
        total = IERC20(self._address).totalSupply();
    }

    function issue(LvAsset memory self, address to, uint256 amount) internal {
        Asset(self._address).mint(to, amount);
    }

    function incLocked(LvAsset storage self, uint256 amount) internal {
        self.locked = self.locked + amount;
    }

    function decLocked(LvAsset storage self, uint256 amount) internal {
        self.locked = self.locked - amount;
    }

    function lockFrom(LvAsset storage self, uint256 amount, address from) internal {
        incLocked(self, amount);
        lockUnchecked(self, amount, from);
    }

    function unlockTo(LvAsset storage self, uint256 amount, address to) internal {
        decLocked(self, amount);
        self.asErc20().safeTransfer(to, amount);
    }

    function lockUnchecked(LvAsset storage self, uint256 amount, address from) internal {
        self.asErc20().safeTransferFrom(from, address(this), amount);
    }
}
