// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Pair} from "./Pair.sol";
import {RedemptionAssetManager} from "./RedemptionAssetManagerLib.sol";
import {LvAsset} from "./LvAssetLib.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {DepegSwap} from "./DepegSwapLib.sol";

/**
 * @dev State structure
 * @dev as there are some fields that are used in PSM but not in LV
 */
struct State {
    /// @dev used to track current ds and ct for both lv and psm
    uint256 globalAssetIdx;
    Pair info;
    /// @dev dsId => DepegSwap(CT + DS)
    mapping(uint256 => DepegSwap) ds;
    PsmState psm;
    VaultState vault;
}

/**
 * @dev PsmState structure for PSM Core
 */
struct PsmState {
    Balances balances;
    uint256 repurchaseFeePercentage;
    uint256 repurchaseFeeTreasurySplitPercentage;
    BitMaps.BitMap liquiditySeparated;
    /// @dev dsId => PsmPoolArchive
    mapping(uint256 => PsmPoolArchive) poolArchive;
    mapping(address => bool) autoSell;
    bool isDepositPaused;
    bool isWithdrawalPaused;
    bool isRepurchasePaused;
    uint256 psmBaseRedemptionFeePercentage;
    uint256 psmBaseFeeTreasurySplitPercentage;
}

/**
 * @dev PsmPoolArchive structure for PSM Pools
 */
struct PsmPoolArchive {
    uint256 raAccrued;
    uint256 paAccrued;
    uint256 ctAttributed;
    uint256 attributedToRolloverProfit;
    /// @dev user => amount
    mapping(address => uint256) rolloverClaims;
    uint256 rolloverProfit;
}

/**
 * @dev Balances structure for managing balances in PSM Core
 */
struct Balances {
    RedemptionAssetManager ra;
    uint256 dsBalance;
    uint256 paBalance;
    uint256 ctBalance;
}

/**
 * @dev Balances structure for managing balances in PSM Core
 */
struct VaultBalances {
    RedemptionAssetManager ra;
    uint256 ctBalance;
    uint256 lpBalance;
}

/**
 * @dev VaultPool structure for providing pools in Vault(Liquidity Pool)
 */
struct VaultPool {
    VaultWithdrawalPool withdrawalPool;
    VaultAmmLiquidityPool ammLiquidityPool;
    /// @dev user => (dsId => amount)
    mapping(address => uint256) withdrawEligible;
}

/**
 * @dev VaultWithdrawalPool structure for providing withdrawal pools in Vault(Liquidity Pool)
 */
struct VaultWithdrawalPool {
    uint256 atrributedLv;
    uint256 raExchangeRate;
    uint256 paExchangeRate;
    uint256 raBalance;
    uint256 paBalance;
}

/**
 * @dev VaultAmmLiquidityPool structure for providing AMM pools in Vault(Liquidity Pool)
 * This should only be used at the end of each epoch(dsId) lifecyle(e.g at expiry) to pool all RA to be used
 * as liquidity for initiating AMM in the next epoch
 */
struct VaultAmmLiquidityPool {
    uint256 balance;
}

/**
 * @dev VaultState structure for VaultCore
 */
struct VaultState {
    VaultBalances balances;
    VaultConfig config;
    LvAsset lv;
    BitMaps.BitMap lpLiquidated;
    VaultPool pool;
    // will be set to true after first deposit to LV.
    // to prevent manipulative behavior when depositing to Lv since we depend on preview redeem early to get
    // the correct exchange rate of LV
    bool initialized;
    /// @notice the percentage of which the RA that user deposit will be split
    /// e.g 40% means that 40% of the RA that user deposit will be splitted into CT and DS
    /// the CT will be held in the vault while the DS is held in the vault reserve to be selled in the router
    uint256 ctHeldPercetage;
    /// @notice dsId => totalRA. will be updated on every new issuance, so dsId 1 would be update at new issuance of dsId 2
    mapping(uint256 => uint256) totalRaSnapshot;
}

/**
 * @dev VaultConfig structure for VaultConfig Contract
 */
struct VaultConfig {
    bool isDepositPaused;
    bool isWithdrawalPaused;
    NavCircuitBreaker navCircuitBreaker;
}

struct NavCircuitBreaker {
    uint256 snapshot0;
    uint256 lastUpdate0;
    uint256 snapshot1;
    uint256 lastUpdate1;
    uint256 navThreshold;
}
