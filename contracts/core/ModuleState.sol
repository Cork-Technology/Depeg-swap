// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {State} from "../libraries/State.sol";
import {ICommon} from "../interfaces/ICommon.sol";
import {PsmLibrary} from "../libraries/PsmLib.sol";
import {IUniswapV2Factory} from "../interfaces/uniswap-v2/factory.sol";
import {RouterState} from "./flash-swaps/FlashSwapRouter.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap-v2/RouterV2.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/**
 * @title ModuleState Abstract Contract
 * @author Cork Team
 * @notice Abstract ModuleState contract for providing base for Modulecore contract
 */
abstract contract ModuleState is ICommon, ReentrancyGuardTransient {
    using PsmLibrary for State;

    mapping(Id => State) internal states;

    address internal SWAP_ASSET_FACTORY;

    address internal DS_FLASHSWAP_ROUTER;

    /// @dev in this case is uni v4
    address internal AMM_HOOK;

    address internal CONFIG;

    /**
     * @dev checks if caller is config contract or not
     */
    modifier onlyConfig() {
        if (msg.sender != CONFIG) {
            revert OnlyConfigAllowed();
        }
        _;
    }

    function factory() external view returns (address) {
        return SWAP_ASSET_FACTORY;
    }

    function initializeModuleState(
        address _swapAssetFactory,
        address _ammHook,
        address _dsFlashSwapRouter,
        address _config
    ) internal {
        if (
            _swapAssetFactory == address(0) || _ammFactory == address(0) || _dsFlashSwapRouter == address(0)
                || _ammRouter == address(0) || _config == address(0)
        ) {
            revert ZeroAddress();
        }

        SWAP_ASSET_FACTORY = _swapAssetFactory;
        DS_FLASHSWAP_ROUTER = _dsFlashSwapRouter;
        CONFIG = _config;
        AMM_HOOK = _ammHook;
    }

    function getRouterCore() internal view returns (RouterState) {
        return RouterState(DS_FLASHSWAP_ROUTER);
    }

    function getAmmRouter() internal view returns (ICorkHook) {
        return ICorkHook(AMM_HOOK);
    }

    modifier onlyInitialized(Id id) {
        if (!states[id].isInitialized()) {
            revert Uninitializedlized();
        }
        _;
    }

    modifier PSMDepositNotPaused(Id id) {
        if (states[id].psm.isDepositPaused) {
            revert PSMDepositPaused();
        }
        _;
    }

    modifier onlyFlashSwapRouter() {
        if (msg.sender != DS_FLASHSWAP_ROUTER) {
            revert OnlyFlashSwapRouterAllowed();
        }
        _;
    }

    modifier PSMWithdrawalNotPaused(Id id) {
        if (states[id].psm.isWithdrawalPaused) {
            revert PSMWithdrawalPaused();
        }
        _;
    }

    modifier PSMRepurchaseNotPaused(Id id) {
        if (states[id].psm.isRepurchasePaused) {
            revert PSMRepurchasePaused();
        }
        _;
    }

    modifier LVDepositNotPaused(Id id) {
        if (states[id].vault.config.isDepositPaused) {
            revert LVDepositPaused();
        }
        _;
    }

    modifier LVWithdrawalNotPaused(Id id) {
        if (states[id].vault.config.isWithdrawalPaused) {
            revert LVWithdrawalPaused();
        }
        _;
    }
}
