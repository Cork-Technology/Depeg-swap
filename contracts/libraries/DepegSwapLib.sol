// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Asset} from "../core/assets/Asset.sol";
import {Signature, MinimalSignatureHelper} from "./SignatureHelperLib.sol";
import {IRates} from "../interfaces/IRates.sol";

struct DepegSwap {
    bool expiredEventEmitted;
    address _address;
    address ct;
    /// @dev right now this the RA:CT AMM pair address
    address ammPair;
    uint256 dsRedeemed;
    uint256 ctRedeemed;
}

library DepegSwapLibrary {
    using MinimalSignatureHelper for Signature;

    function isExpired(DepegSwap storage self) internal view returns (bool) {
        return Asset(self._address).isExpired();
    }

    function isInitialized(DepegSwap storage self) internal view returns (bool) {
        return self._address != address(0) && self.ct != address(0);
    }

    function exchangeRate(DepegSwap storage self) internal view returns (uint256) {
        return Asset(self._address).exchangeRate();
    }

    function rates(DepegSwap storage self) internal view returns (uint256 rate) {
        uint256 dsRate = IRates(self._address).exchangeRate();
        uint256 ctRate = IRates(self.ct).exchangeRate();

        assert(dsRate == ctRate);
        rate = dsRate;
    }

    function initialize(address _address, address ct, address ammPair) internal pure returns (DepegSwap memory) {
        return DepegSwap({
            expiredEventEmitted: false,
            _address: _address,
            ammPair: ammPair,
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

        Asset(contract_).permit(owner, spender, value, deadline, sig.v, sig.r, sig.s);
    }

    function issue(DepegSwap memory self, address to, uint256 amount) internal {
        Asset(self._address).mint(to, amount);
        Asset(self.ct).mint(to, amount);
    }

    function burnBothforSelf(DepegSwap storage self, uint256 amount) internal {
        Asset(self._address).burn(amount);
        Asset(self.ct).burn(amount);
    }
}
