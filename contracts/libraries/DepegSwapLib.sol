// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./../Asset.sol";
import "./SignatureHelperLib.sol";

struct DepegSwap {
    bool expiredEventEmitted;
    address ds;
    address ct;
    uint256 dsRedeemed;
    uint256 ctRedeemed;
}

library DepegSwapLibrary {
    using MinimalSignatureHelper for Signature;

    function isExpired(DepegSwap storage self) internal view returns (bool) {
        return Asset(self.ds).isExpired();
    }

    function isInitialized(
        DepegSwap storage self
    ) internal view returns (bool) {
        return self.ds != address(0) && self.ct != address(0);
    }

    function exchangeRate(
        DepegSwap storage self
    ) internal view returns (uint256) {
        return Asset(self.ds).exchangeRate();
    }

    function initialize(
        address ds,
        address ct
    ) internal pure returns (DepegSwap memory) {
        return
            DepegSwap({
                expiredEventEmitted: false,
                ds: ds,
                ct: ct,
                dsRedeemed: 0,
                ctRedeemed: 0
            });
    }

    function permit(
        address contract_,
        bytes memory rawSig,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal {
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        Asset(contract_).permit(
            owner,
            spender,
            value,
            deadline,
            sig.v,
            sig.r,
            sig.s
        );
    }

    function issue(DepegSwap memory self, address to, uint256 amount) internal {
        Asset(self.ds).mint(to, amount);
        Asset(self.ct).mint(to, amount);
    }

    function burnBothforSelf(DepegSwap storage self, uint256 amount) internal {
        Asset(self.ds).burn(amount);
        Asset(self.ct).burn(amount);
    }
}
