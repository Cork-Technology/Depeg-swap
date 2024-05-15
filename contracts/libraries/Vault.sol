// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VaultConfig.sol";
import "./PairKey.sol";
import "./LvLib.sol";

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
    
    function initialize(
        VaultState storage self,
        PairKey memory key,
        address lvAsset,
        uint256 fee,
        uint256 waConvertThreshold,
        uint256 ammDepositThreshold,
        uint256 ammWaBalance
    ) internal {
        self.key = key;
        self.lvAsset = LvAsset({_address: lvAsset});
        self.config = VaultConfigLibrary.initialize(
            fee,
            waConvertThreshold,
            ammDepositThreshold,
            ammWaBalance
        );
    }
}
