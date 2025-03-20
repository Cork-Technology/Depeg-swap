pragma solidity ^0.8.24;

import {ModuleCore} from "contracts/core/ModuleCore.sol";
import {Id, Pair} from "contracts/libraries/Pair.sol";
import {
    State,
    PsmPoolArchive,
    VaultState,
    VaultAmmLiquidityPool,
    Balances,
    VaultConfig,
    VaultBalances,
    VaultWithdrawalPool
} from "contracts/libraries/State.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {DepegSwap} from "contracts/libraries/DepegSwapLib.sol";
import {LvAsset} from "contracts/libraries/LvAssetLib.sol";
import {StateView} from "contracts/core/StateView.sol";

/// @title TestModuleCore Contract, used for testing ModuleCore contract, mostly here for getter functions
contract TestModuleCore is ModuleCore, StateView {}
