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

// TODO : to PSM balance
struct Balances {
    PsmRedemptionAssetManager ra;
    uint256 dsBalance;
    uint256 ctBalance;
    uint256 paBalance;
}

struct VaultPool {
    VaultWithdrawalPool withdrawalPool;
    VaultAmmLiquidityPool ammLiquidityPool;
}
struct VaultWithdrawalPool {
    uint256 atrributedLv;
    uint256 raExchangeRate;
    uint256 paExchangeRate;
    uint256 raBalance; 
    uint256 paBalance;
    // FIXME : this is only temporary, for now
    // we trate PA the same as RA, thus we also separate PA
    // the difference is the PA here isn't being used as anything
    // and for now will just sit there until rationed again at next expiry.
    uint256 stagnatedPaBalance;
}
struct VaultAmmLiquidityPool {
    uint256 balance;
}

struct VaultState {
    Balances balances;
    VaultConfig config;
    LvAsset lv;
    /// @dev user => (dsId => amount)
    mapping(address => uint256) withdrawEligible;
    BitMaps.BitMap lpLiquidated;
    VaultPool pool;
}
