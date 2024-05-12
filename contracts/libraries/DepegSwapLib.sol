// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./../Asset.sol";
import "./SignatureHelperLib.sol";

struct DepegSwap {
    address depegSwap;
    address coverToken;
    uint256 expiryTimestamp;
}

library DepegSwapLibrary {
    using MinimalSignatureHelper for Signature;

    function isExpired(DepegSwap memory self) internal view returns (bool) {
        return block.timestamp >= self.expiryTimestamp;
    }

    function isInitialized(DepegSwap memory self) internal pure returns (bool) {
        return self.depegSwap != address(0) && self.coverToken != address(0);
    }

    function initialize(
        string memory pairName,
        uint256 expiry
    ) internal returns (DepegSwap memory) {
        return
            DepegSwap({
                depegSwap: address(new Asset("DS", pairName)),
                coverToken: address(new Asset("CT", pairName)),
                expiryTimestamp: expiry
            });
    }

    function dsSupply(DepegSwap memory self) internal view returns (uint256) {
        return Asset(self.depegSwap).totalSupply();
    }

    function ctSupply(DepegSwap memory self) internal view returns (uint256) {
        return Asset(self.coverToken).totalSupply();
    }

    function asAsset(DepegSwap memory self) internal pure returns (Asset) {
        return Asset(self.depegSwap);
    }

    function permit(
        DepegSwap memory self,
        bytes memory rawSig,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal {
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        Asset(self.depegSwap).permit(
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
        Asset(self.depegSwap).mint(to, amount);
        Asset(self.coverToken).mint(to, amount);
    }
}
