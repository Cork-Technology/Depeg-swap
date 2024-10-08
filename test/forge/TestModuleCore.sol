pragma solidity ^0.8.24;

import {ModuleCore} from "./../../contracts/core/ModuleCore.sol";
import {Id, Pair} from "../../contracts/libraries/Pair.sol";
import {
    State,
    PsmPoolArchive,
    VaultState,
    VaultAmmLiquidityPool,
    Balances,
    VaultConfig,
    VaultWithdrawalPool
} from "../../contracts/libraries/State.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {DepegSwap} from "../../contracts/libraries/DepegSwapLib.sol";
import {LvAsset} from "../../contracts/libraries/LvAssetLib.sol";

/// @title TestModuleCore Contract, used for testing ModuleCore contract, mostly here for getter functions
contract TestModuleCore is ModuleCore {
    using BitMaps for BitMaps.BitMap;

    constructor() {}

    // ------------------------------ GLOBAL GETTERS ------------------------------
    function getDsId(Id id) external view returns (uint256) {
        return states[id].globalAssetIdx;
    }

    function getPairInfo(Id id) external view returns (Pair memory) {
        return states[id].info;
    }

    function getDs(Id id, uint256 dsId) external view returns (DepegSwap memory) {
        return states[id].ds[dsId];
    }
    //--------------------------------------------------------------------------------

    // ------------------------------ PSM GETTERS ------------------------------
    function getPsmBalances(Id id) external view returns (Balances memory) {
        return states[id].psm.balances;
    }

    function getPsmPoolArchiveRaAccrued(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].raAccrued;
    }

    function getPsmPoolArchivePaAccrued(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].paAccrued;
    }

    function getPsmPoolArchiveCtAttributed(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].ctAttributed;
    }

    function getPsmPoolArchiveAttributedToRollover(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].attributedToRolloverProfit;
    }

    function getPsmPoolArchiveRolloverClaims(Id id, uint256 dsId, address user) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].rolloverClaims[user];
    }

    function getPsmPoolArchiveRolloverProfit(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].rolloverProfit;
    }

    function getPsmRepurchaseFeePercentage(Id id) external view returns (uint256) {
        return states[id].psm.repurchaseFeePercentage;
    }

    function getPsmLiquiditySeparated(Id id, uint256 dsId) external view returns (bool) {
        return states[id].psm.liquiditySeparated.get(dsId);
    }

    function getPsmIsDepositPaused(Id id) external view returns (bool) {
        return states[id].psm.isDepositPaused;
    }

    function getPsmIsWithdrawalPaused(Id id) external view returns (bool) {
        return states[id].psm.isWithdrawalPaused;
    }
    //--------------------------------------------------------------------------------

    // ------------------------------ VAULT GETTERS ------------------------------
    function getVaultBalances(Id id) external view returns (Balances memory) {
        return states[id].vault.balances;
    }

    function getVaultConfig(Id id) external view returns (VaultConfig memory) {
        return states[id].vault.config;
    }

    function getVaultLvAsset(Id id) external view returns (LvAsset memory) {
        return states[id].vault.lv;
    }

    function getVaultLpLiquidated(Id id, uint256 dsId) external view returns (bool) {
        return states[id].vault.lpLiquidated.get(dsId);
    }

    function getVaultWithdrawalPool(Id id) external view returns (VaultWithdrawalPool memory) {
        return states[id].vault.pool.withdrawalPool;
    }

    function getVaultAmmLiquidityPool(Id id) external view returns (VaultAmmLiquidityPool memory) {
        return states[id].vault.pool.ammLiquidityPool;
    }

    function getWithdrawEligible(Id id, address user) external view returns (uint256) {
        return states[id].vault.pool.withdrawEligible[user];
    }
    // --------------------------------------------------------------------------------
}
