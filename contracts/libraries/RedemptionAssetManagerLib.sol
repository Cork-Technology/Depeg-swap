// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./../Asset.sol";
import "./SignatureHelperLib.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../WrappedAsset.sol";
import "./DepegSwapLib.sol";

struct RedemptionAssetManager {
    address _address;
    uint256 locked;
    uint256 free;
}

library RedemptionAssetManagerLibrary {
    using MinimalSignatureHelper for Signature;

    function initialize(
        address ra
    ) internal pure returns (RedemptionAssetManager memory) {
        return RedemptionAssetManager(ra, 0, 0);
    }

    function incLocked(
        RedemptionAssetManager storage self,
        uint256 amount
    ) internal {
        self.locked = self.locked + amount;
    }

    function incFree(
        RedemptionAssetManager storage self,
        uint256 amount
    ) internal {
        self.free = self.free + amount;
    }

    function decFree(
        RedemptionAssetManager storage self,
        uint256 amount
    ) internal {
        self.free = self.free - amount;
    }

    function convertAllToFree(
        RedemptionAssetManager storage self
    ) internal returns (uint256) {
        if (self.locked == 0) {
            return self.free;
        }

        self.free = self.free + self.locked;
        self.locked = 0;

        return self.free;
    }

    function tryConvertAllToFree(
        RedemptionAssetManager storage self
    ) internal view returns (uint256) {
        if (self.locked == 0) {
            return self.free;
        }

        return self.free + self.locked;
    }

    function decLocked(
        RedemptionAssetManager storage self,
        uint256 amount
    ) internal {
        self.locked = self.locked - amount;
    }

    function circulatingSupply(
        RedemptionAssetManager memory self
    ) internal view returns (uint256) {
        return IERC20(self._address).totalSupply() - self.locked;
    }

    function lockFrom(
        RedemptionAssetManager storage self,
        uint256 amount,
        address from
    ) internal {
        incLocked(self, amount);
        lockUnchecked(self, amount, from);
    }

    function lockUnchecked(
        RedemptionAssetManager storage self,
        uint256 amount,
        address from
    ) internal {
        IERC20(self._address).transferFrom(from, address(this), amount);
    }

    function unlockTo(
        RedemptionAssetManager storage self,
        address to,
        uint256 amount
    ) internal {
        decLocked(self, amount);
        unlockToUnchecked(self, amount, to);
    }

    function unlockToUnchecked(
        RedemptionAssetManager storage self,
        uint256 amount,
        address to
    ) internal {
        IERC20(self._address).transfer(to, amount);
    }
}
