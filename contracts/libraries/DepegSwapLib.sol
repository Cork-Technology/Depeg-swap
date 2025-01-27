// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Asset} from "../core/assets/Asset.sol";
import {Signature, MinimalSignatureHelper} from "./SignatureHelperLib.sol";

/**
 * @dev DepegSwap structure for DS(DepegSwap)
 */
struct DepegSwap {
    bool expiredEventEmitted;
    address _address;
    address ct;
    uint256 ctRedeemed;
}

/**
 * @title DepegSwapLibrary Contract
 * @author Cork Team
 * @notice DepegSwapLibrary library which implements DepegSwap(DS) related features
 */
library DepegSwapLibrary {
    using MinimalSignatureHelper for Signature;

    /// @notice the exchange rate of DS can only go down at maximum 10% at a time
    uint256 internal constant MAX_RATE_DELTA_PERCENTAGE = 10e18;
    
    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    function isExpired(DepegSwap storage self) internal view returns (bool) {
        return Asset(self._address).isExpired();
    }

    function isInitialized(DepegSwap storage self) internal view returns (bool) {
        return self._address != address(0) && self.ct != address(0);
    }

    function exchangeRate(DepegSwap storage self) internal view returns (uint256) {
        return Asset(self._address).exchangeRate();
    }

    function initialize(address _address, address ct) internal pure returns (DepegSwap memory) {
        if(_address == address(0) || ct == address(0)) {
            revert ZeroAddress();
        }
        return DepegSwap({expiredEventEmitted: false, _address: _address, ct: ct, ctRedeemed: 0});
    }

    function permitForRA(
        address contract_,
        bytes memory rawSig,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal {
        // Split the raw signature
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        // Call the underlying ERC-20 contract's permit function
        IERC20Permit(contract_).permit(owner, spender, value, deadline, sig.v, sig.r, sig.s);
    }

    function permit(
        address contract_,
        bytes memory rawSig,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        string memory functionName
    ) internal {
        // Split the raw signature
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        // Call the underlying ERC-20 contract's permit function
        Asset(contract_).permit(owner, spender, value, deadline, sig.v, sig.r, sig.s, functionName);
    }

    function issue(DepegSwap memory self, address to, uint256 amount) internal {
        Asset(self._address).mint(to, amount);
        Asset(self.ct).mint(to, amount);
    }

    function burnCtSelf(DepegSwap storage self, uint256 amount) internal {
        Asset(self.ct).burn(amount);
    }

    function updateExchangeRate(DepegSwap storage self, uint256 rate) internal {
        Asset(self._address).updateRate(rate);
        Asset(self.ct).updateRate(rate);
    }
}
