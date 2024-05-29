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

    function circulatingSupply(
        WrappedAssetInfo memory self
    ) internal view returns (uint256) {
        return IERC20(self._address).totalSupply() - self.locked;
    }

    function lock(WrappedAssetInfo storage self, uint256 amount) internal {
        self.locked = self.locked + amount;

        IERC20 underlying = ERC20Wrapper(self._address).underlying();
        underlying.transferFrom(msg.sender, address(this), amount);
        underlying.approve(self._address, amount);
        WrappedAsset(self._address).wrap(amount);
    }

    function unlock(WrappedAssetInfo storage self, uint256 amount) internal {
        self.locked = self.locked - amount;
        
        WrappedAsset(self._address).unwrap(amount);
        IERC20 underlying = ERC20Wrapper(self._address).underlying();
        underlying.transfer(msg.sender, amount);
    }
}

// TODO : fix this, move this to a dedicated wrapper contract, and make a factory our of it