// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VaultConfig.sol";
import "./PairKey.sol";
import "./LvLib.sol";
import "./PSMLib.sol";
import "./WrappedAssetLib.sol";

struct VaultState {
    VaultConfig config;
    PairKey key;
    LvAsset lvAsset;
}

library VaultLibrary {
    using VaultConfigLibrary for VaultConfig;
    using PairKeyLibrary for PairKey;
    using LvAssetLibrary for LvAsset;
    using VaultLibrary for VaultState;
    using PSMLibrary for PsmState;
    using WrappedAssetLibrary for WrappedAsset;

    function initialize(
        VaultState storage self,
        PairKey memory key,
        address lvAsset,
        uint256 fee,
        uint256 waConvertThreshold,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold
    ) internal {
        self.key = key;
        self.lvAsset = LvAsset({_address: lvAsset});
        self.config = VaultConfigLibrary.initialize(
            fee,
            waConvertThreshold,
            ammWaDepositThreshold,
            ammCtDepositThreshold
        );
    }

    function _provideCtAmmLiquidity(uint256 ct) internal {
        // placeholder
    }

    function _provideWaAmmLiquidity(uint256 wa) internal {
        // placeholder
    }

    function _limitOrderDs(uint256 amount) internal {
        // placeholder
    }

    function deposit(
        VaultState storage self,
        PsmState storage psm,
        address from,
        uint256 amount
    ) internal {
        (uint256 locked, uint256 free) = self.config.calcWa(amount);
        self.config.increaseWaBalance(free);
        self.config.increaseCtBalance(locked);
        
        // psm.wa.issueAndLock(locked);
        
        self.lvAsset.issue(from, amount);

        if (self.config.mustDepositWaAmm()) {
            _provideWaAmmLiquidity(free);
        }

        if (self.config.mustDepositCtAmm()) {
            _provideCtAmmLiquidity(locked);
        }

        _limitOrderDs(locked);
    }

    // preview a deposit action with current exchange rate,
    // returns the amount of shares(share pool token) that user will receive
    function previewDeposit(
        uint256 amount
    ) external pure returns (uint256 lvReceived){
        lvReceived = amount;
    }
}
