// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {State} from "../libraries/State.sol";
import {ICommon} from "../interfaces/ICommon.sol";
import {PsmLibrary} from "../libraries/PsmLib.sol";
import {RouterState} from "./flash-swaps/FlashSwapRouter.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {ILiquidatorRegistry} from "./../interfaces/ILiquidatorRegistry.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Withdrawal} from "./Withdrawal.sol";

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

    address internal WITHDRAWAL_CONTRACT;

    /**
     * @dev checks if caller is config contract or not
     */
    function onlyConfig() internal {
        if (msg.sender != CONFIG) {
            revert OnlyConfigAllowed();
        }
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

    function _setWithdrawalContract(address _withdrawalContract) internal{
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

    function onlyInitialized(Id id) internal {
        if (!states[id].isInitialized()) {
            revert Uninitialized();
        }
    }

    function PSMDepositNotPaused(Id id) internal {
        if (states[id].psm.isDepositPaused) {
            revert PSMDepositPaused();
        }
    }

    function onlyFlashSwapRouter() internal {
        if (msg.sender != DS_FLASHSWAP_ROUTER) {
            revert OnlyFlashSwapRouterAllowed();
        }
    }

    function PSMWithdrawalNotPaused(Id id) internal {
        if (states[id].psm.isWithdrawalPaused) {
            revert PSMWithdrawalPaused();
        }
    }

    function PSMRepurchaseNotPaused(Id id) internal {
        if (states[id].psm.isRepurchasePaused) {
            revert PSMRepurchasePaused();
        }
    }

    function LVDepositNotPaused(Id id) internal {
        if (states[id].vault.config.isDepositPaused) {
            revert LVDepositPaused();
        }
    }

    function LVWithdrawalNotPaused(Id id) internal {
        if (states[id].vault.config.isWithdrawalPaused) {
            revert LVWithdrawalPaused();
        }
    }

    function onlyWhiteListedLiquidationContract() internal {
        if (!ILiquidatorRegistry(CONFIG).isLiquidationWhitelisted(msg.sender)) {
            revert OnlyWhiteListed();
        }
    }
}
