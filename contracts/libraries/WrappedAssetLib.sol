// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./../Asset.sol";
import "./SignatureHelperLib.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./../WrappedAsset.sol";
import "./DepegSwapLib.sol";

struct WrappedAssetInfo {
    address _address;
    uint256 locked;
}

library WrappedAssetLibrary {
    using MinimalSignatureHelper for Signature;

    function initialize(
        address wa
    ) internal pure returns (WrappedAssetInfo memory) {
        return WrappedAssetInfo({_address: wa, locked: 0});
    }

    function incLocked(WrappedAssetInfo storage self, uint256 amount) internal {
        self.locked = self.locked + amount;
    }

    function decLocked(WrappedAssetInfo storage self, uint256 amount) internal {
        self.locked = self.locked - amount;
    }

    function circulatingSupply(
        WrappedAssetInfo memory self
    ) internal view returns (uint256) {
        return IERC20(self._address).totalSupply() - self.locked;
    }

    function approveAndWrap(address _address, uint256 amount) internal {
        IERC20 underlying = ERC20Wrapper(_address).underlying();
        underlying.approve(_address, amount);
        WrappedAsset(_address).wrap(amount);
    }

    function lockFrom(
        WrappedAssetInfo storage self,
        uint256 amount,
        address from
    ) internal {
        incLocked(self, amount);
        lockUnchecked(self, amount, from);
    }

    function lockUnchecked(
        WrappedAssetInfo storage self,
        uint256 amount,
        address from
    ) internal {
        IERC20 underlying = ERC20Wrapper(self._address).underlying();
        underlying.transferFrom(from, address(this), amount);
        approveAndWrap(self._address, amount);
    }

    function unlockTo(
        WrappedAssetInfo storage self,
        address to,
        uint256 amount
    ) internal {
        decLocked(self, amount);
        unlockToUnchecked(self, amount, to);
    }

    function unlockToUnchecked(
        WrappedAssetInfo storage self,
        uint256 amount,
        address to
    ) internal {
        WrappedAsset(self._address).unwrapTo(to, amount);
    }
}
