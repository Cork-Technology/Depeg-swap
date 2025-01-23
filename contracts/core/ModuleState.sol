// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {State} from "../libraries/State.sol";
import {IErrors} from "./../interfaces/IErrors.sol";
import {PsmLibrary} from "../libraries/PsmLib.sol";
import {RouterState} from "./flash-swaps/FlashSwapRouter.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {ILiquidatorRegistry} from "./../interfaces/ILiquidatorRegistry.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Withdrawal} from "./Withdrawal.sol";
import {CorkConfig} from "./CorkConfig.sol";

/**
 * @title ModuleState Abstract Contract
 * @author Cork Team
 * @notice Abstract ModuleState contract for providing base for Modulecore contract
 */
abstract contract ModuleState is IErrors, ReentrancyGuardTransient {
    using PsmLibrary for State;

    mapping(Id => State) internal states;

    address internal SWAP_ASSET_FACTORY;

    address internal DS_FLASHSWAP_ROUTER;

    /// @dev in this case is uni v4
    address internal AMM_HOOK;

    address internal CONFIG;

    address internal WITHDRAWAL_CONTRACT;

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
            _swapAssetFactory == address(0) || _ammHook == address(0) || _dsFlashSwapRouter == address(0)
                || _config == address(0)
        ) {
            revert ZeroAddress();
        }

        SWAP_ASSET_FACTORY = _swapAssetFactory;
        DS_FLASHSWAP_ROUTER = _dsFlashSwapRouter;
        CONFIG = _config;
        AMM_HOOK = _ammHook;
    }

    function _setWithdrawalContract(address _withdrawalContract) internal {
        WITHDRAWAL_CONTRACT = _withdrawalContract;
    }

    function getRouterCore() internal view returns (RouterState) {
        return RouterState(DS_FLASHSWAP_ROUTER);
    }

    function getAmmRouter() internal view returns (ICorkHook) {
        return ICorkHook(AMM_HOOK);
    }

    function getWithdrawalContract() internal view returns (Withdrawal) {
        return Withdrawal(WITHDRAWAL_CONTRACT);
    }

    function getTreasuryAddress() internal view returns (address) {
        return CorkConfig(CONFIG).treasury();
    }

    function onlyInitialized(Id id) internal view {
        if (!states[id].isInitialized()) {
            revert NotInitialized();
        }
    }

    function PSMDepositNotPaused(Id id) internal view {
        if (states[id].psm.isDepositPaused) {
            revert PSMDepositPaused();
        }
    }

    modifier onlyFlashSwapRouter() {
        if (msg.sender != DS_FLASHSWAP_ROUTER) {
            revert OnlyFlashSwapRouterAllowed();
        }
        _;
    }

    function PSMWithdrawalNotPaused(Id id) internal view {
        if (states[id].psm.isWithdrawalPaused) {
            revert PSMWithdrawalPaused();
        }
    }

    function PSMRepurchaseNotPaused(Id id) internal view {
        if (states[id].psm.isRepurchasePaused) {
            revert PSMRepurchasePaused();
        }
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

    function onlyWhiteListedLiquidationContract() internal view {
        if (!ILiquidatorRegistry(CONFIG).isLiquidationWhitelisted(msg.sender)) {
            revert OnlyWhiteListed();
        }
    }
}
