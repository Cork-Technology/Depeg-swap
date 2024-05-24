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

    function lock(
        WrappedAssetInfo memory self,
        bytes memory rawSig,
        uint256 amount,
        address owner,
        address spender,
        uint256 deadline
    ) internal {
        self.locked += amount;
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        IERC20Permit(self._address).permit(
            owner,
            spender,
            amount,
            deadline,
            sig.v,
            sig.r,
            sig.s
        );

        IERC20(self._address).transferFrom(owner, address(this), amount);
    }
}

// TODO : fix this, move this to a dedicated wrapper contract, and make a factory our of it
