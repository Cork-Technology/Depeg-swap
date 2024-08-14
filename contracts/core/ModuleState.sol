// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../libraries/Pair.sol";
import "../libraries/State.sol";
import "../interfaces/IAssetFactory.sol";
import "../interfaces/ICommon.sol";
import "../libraries/PsmLib.sol";
import "../interfaces/uniswap-v2/factory.sol";
import "./flash-swaps/RouterState.sol";
import "../interfaces/uniswap-v2/RouterV2.sol";
import "../libraries/MutexLock.sol";

abstract contract ModuleState is ICommon {
    using PsmLibrary for State;

    mapping(Id => State) internal states;
    address swapAssetFactory;

    /// @dev in this case is uni v2
    address ammFactory;

    address dsFlashSwapRouter;

    /// @dev in this case is uni v2
    address ammRouter;

    address config;

    /** @dev checks if caller is config contract or not
     */
    modifier onlyConfig() {
        if (msg.sender != config) {
            revert OnlyConfigAllowed();
        }
        _;
    }

    function factory() external view returns (address) {
        return swapAssetFactory;
    }

    constructor(
        address _swapAssetFactory,
        address _ammFactory,
        address _dsFlashSwapRouter,
        address _ammRouter,
        address _config
    ) {
        swapAssetFactory = _swapAssetFactory;
        ammFactory = _ammFactory;
        dsFlashSwapRouter = _dsFlashSwapRouter;
        ammRouter = _ammRouter;
        config = _config;
    }

    function getSwapAssetFactory() internal view returns (IAssetFactory) {
        return IAssetFactory(swapAssetFactory);
    }

    function getRouterCore() internal view returns (RouterState) {
        return RouterState(dsFlashSwapRouter);
    }

    function getAmmFactory() internal view returns (IUniswapV2Factory) {
        return IUniswapV2Factory(ammFactory);
    }

    function getAmmRouter() internal view returns (IUniswapV2Router02) {
        return IUniswapV2Router02(ammRouter);
    }

    modifier onlyInitialized(Id id) {
        if (!states[id].isInitialized()) {
            revert Uinitialized();
        }
        _;
    }

    modifier PSMDepositNotPaused(Id id) {
        if (states[id].psm.isDepositPaused) {
            revert PSMDepositPaused();
        }
        _;
    }

    modifier PSMWithdrawalNotPaused(Id id) {
        if (states[id].psm.isWithdrawalPaused) {
            revert PSMWithdrawalPaused();
        }
        _;
    }

    modifier LVDepositNotPaused(Id id) {
        if (states[id].vault.config.isWithdrawalPaused) {
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

    function _onlyValidAsset(address asset) internal view {
        if (getSwapAssetFactory().isDeployed(asset) == false) {
            revert InvalidAsset(asset);
        }
    }

    /// @notice This will revert if the contract is locked
    modifier nonReentrant() {
        if (MutexLock.isLocked()) revert StateLocked();
        MutexLock.lock();
        _;
        MutexLock.unlock();
    }
}
