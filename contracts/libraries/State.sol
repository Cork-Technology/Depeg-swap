// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PairKey.sol";
import "./WrappedAssetLib.sol";
import "./VaultConfig.sol";
import "./LvAssetLib.sol";

struct State {
    /// @dev used to track current
    uint256 globalAssetIdx;
    uint256 totalCtIssued;
    WrappedAssetInfo wa;
    PairKey info;
    mapping(uint256 => DepegSwap) ds;
    VaultState vault;
}

struct PsmState {
    uint256 totalCtIssued;
}

struct VaultState {
    VaultConfig config;
    mapping(uint256 => LvAsset) lv;
    mapping(address => bool) withdrawEligible;
}
