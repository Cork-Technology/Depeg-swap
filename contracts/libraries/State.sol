// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Pair.sol";
import "./WrappedAssetLib.sol";
import "./VaultConfig.sol";
import "./LvAssetLib.sol";

struct State {
    /// @dev used to track current ds and ct for both lv and psm
    uint256 globalAssetIdx;
    WrappedAssetInfo wa;
    Pair info;
    mapping(uint256 => DepegSwap) ds;
    VaultState vault;
}

struct PsmState {
    uint256 totalCtIssued;
}

struct VaultState {
    VaultConfig config;
    LvAsset lv;
    mapping(address => bool) withdrawEligible;
    bool lpLiquidated;
}
