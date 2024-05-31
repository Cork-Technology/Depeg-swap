// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PairKey.sol";
import "./WrappedAssetLib.sol";
import "./VaultConfig.sol";
import "./LvAssetLib.sol";


struct State {
    uint256 dsCount;
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
    LvAsset lv;
    mapping(address => bool) withdrawEligible;
}