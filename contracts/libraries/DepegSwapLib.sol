pragma solidity 0.8.24;

import {Asset} from "../core/assets/Asset.sol";
import {Signature, MinimalSignatureHelper} from "./SignatureHelperLib.sol";

/**
 * @dev DepegSwap structure for DS(DepegSwap)   
 */
struct DepegSwap {
    bool expiredEventEmitted;
    address _address;
    address ct;
    /// @dev right now this the RA:CT AMM pair address
    address ammPair;
    uint256 ctRedeemed;
}

/**
 * @title DepegSwapLibrary Contract
 * @author Cork Team
 * @notice DepegSwapLibrary library which implements DepegSwap(DS) related features 
 */
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

    function initialize(address _address, address ct, address ammPair) internal pure returns (DepegSwap memory) {
        return DepegSwap({expiredEventEmitted: false, _address: _address, ammPair: ammPair, ct: ct, ctRedeemed: 0});
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
