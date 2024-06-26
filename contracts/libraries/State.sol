// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Pair.sol";
import "./RedemptionAssetManagerLib.sol";
import "./VaultConfig.sol";
import "./LvAssetLib.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

// TODO : should refactor this into distinct structs for psm and lv states, especially the balances
// as there are some fields that are used in PSM but not in LV
struct State {
    /// @dev used to track current ds and ct for both lv and psm
    uint256 globalAssetIdx;
    Pair info;
    mapping(uint256 => DepegSwap) ds;
    Balances psmBalances;
    VaultState vault;
}

struct Balances {
    RedemptionAssetManager ra;
    uint256 dsBalance;
    uint256 ctBalance;
    uint256 paBalance;
    uint256 totalCtIssued;
}

struct VaultState {
    Balances balances;
    VaultConfig config;
    LvAsset lv;
    /// @dev user => (dsId => amount)
    mapping(address => uint256) withdrawEligible;
    BitMaps.BitMap lpLiquidated;
}
