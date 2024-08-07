// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Pair.sol";
import "./RedemptionAssetManagerLib.sol";
import "./VaultConfig.sol";
import "./LvAssetLib.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

// as there are some fields that are used in PSM but not in LV
struct State {
    /// @dev used to track current ds and ct for both lv and psm
    uint256 globalAssetIdx;
    Pair info;
    /// @dev dsId => DepegSwap(CT + DS)
    mapping(uint256 => DepegSwap) ds;
    PsmState psm;
    VaultState vault;
}

struct PsmState {
    Balances balances;
    // TODO : make a function to update this
    uint256 repurchaseFeePrecentage;
    BitMaps.BitMap liquiditySeparated;
    /// @dev dsId => PsmPoolArchive
    mapping(uint256 => PsmPoolArchive) poolArchive;
    bool isDepositPaused;
    bool isWithdrawalPaused;
}

struct PsmPoolArchive {
    uint256 raAccrued;
    uint256 paAccrued;
    uint256 ctAttributed;
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
    /// @dev user => (dsId => amount)
    mapping(address => uint256) withdrawEligible;
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
    BitMaps.BitMap lpLiquidated;
    VaultPool pool;
}

// TODO : remove all threshold
struct VaultConfig {
    // 1 % = 1e18
    uint256 fee;
    //
    uint256 lpRaBalance;
    uint256 ammRaDepositThreshold;
    //
    uint256 ammCtDepositThreshold;
    uint256 lpCtBalance;
    // 
    uint256 lpBalance;
    bool isDepositPaused;
    bool isWithdrawalPaused;
}
