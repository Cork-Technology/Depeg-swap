pragma solidity 0.8.24;

import {Pair} from "./Pair.sol";
import {PsmRedemptionAssetManager} from "./RedemptionAssetManagerLib.sol";
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
    uint256 repurchaseFeePrecentage;
    BitMaps.BitMap liquiditySeparated;
    /// @dev dsId => PsmPoolArchive
    mapping(uint256 => PsmPoolArchive) poolArchive;
    bool isDepositPaused;
    bool isWithdrawalPaused;
}

/**
 * @dev PsmPoolArchive structure for PSM Pools
 */
struct PsmPoolArchive {
    uint256 raAccrued;
    uint256 paAccrued;
    uint256 ctAttributed;
}

/**
 * @dev Balances structure for managing balances in PSM Core
 */
struct Balances {
    PsmRedemptionAssetManager ra;
    uint256 dsBalance;
    uint256 ctBalance;
    uint256 paBalance;
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
    // FIXME : this is only temporary, for now
    // we trate PA the same as RA, thus we also separate PA
    // the difference is the PA here isn't being used as anything
    // and for now will just sit there until rationed again at next expiry.
    uint256 stagnatedPaBalance;
}

/**
 * @dev VaultAmmLiquidityPool structure for providing AMM pools in Vault(Liquidity Pool)
 */
struct VaultAmmLiquidityPool {
    uint256 balance;
}

/**
 * @dev VaultState structure for VaultCore
 */
struct VaultState {
    Balances balances;
    VaultConfig config;
    LvAsset lv;
    BitMaps.BitMap lpLiquidated;
    VaultPool pool;
    uint256 initialDsPrice;
}

/**
 * @dev VaultConfig structure for VaultConfig Contract
 */
struct VaultConfig {
    // 1 % = 1e18
    uint256 fee;
    uint256 lpBalance;
    bool isDepositPaused;
    bool isWithdrawalPaused;
}
