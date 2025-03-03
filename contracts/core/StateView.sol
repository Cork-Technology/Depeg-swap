// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ModuleState} from "./ModuleState.sol";
import {Id, Pair} from "./../libraries/Pair.sol";
import {DepegSwap} from "./../libraries/DepegSwapLib.sol";
import {
    VaultAmmLiquidityPool, Balances, VaultConfig, VaultBalances, VaultWithdrawalPool
} from "./../libraries/State.sol";
import {LvAsset} from "./../libraries/LvAssetLib.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

/// @title StateView Contract, used for providing getter functions for ModuleCore contract
/// intended usage is to run a local fork of blockchain and replace the bytecode of ModuleCore contract with this contract
contract StateView is ModuleState {
    using BitMaps for BitMaps.BitMap;

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
    function getVaultBalances(Id id) external view returns (VaultBalances memory) {
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
