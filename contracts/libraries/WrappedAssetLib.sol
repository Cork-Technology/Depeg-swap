// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./../Asset.sol";
import "./SignatureHelperLib.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./../WrappedAsset.sol";

struct WrappedAssetInfo {
    address wa;
    uint256 locked;
}

library WrappedAssetLibrary {
    using MinimalSignatureHelper for Signature;

    function initialize(
        address wa
    ) internal pure returns (WrappedAssetInfo memory) {
        return WrappedAssetInfo({wa: wa, locked: 0});
    }

    function circulatingSupply(
        WrappedAssetInfo memory self
    ) internal view returns (uint256) {
        return IERC20(self.wa).totalSupply() - self.locked;
    }

    function Lock(
        WrappedAssetInfo memory self,
        bytes memory rawSig,
        uint256 amount,
        address owner,
        address spender,
        uint256 deadline
    ) internal {
        self.locked += amount;
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        IERC20Permit(self.wa).permit(
            owner,
            spender,
            amount,
            deadline,
            sig.v,
            sig.r,
            sig.s
        );
    }
}

// TODO : fix this, move this to a dedicated wrapper contract, and make a factory our of it
