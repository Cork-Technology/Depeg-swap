// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Id} from "../libraries/Pair.sol";
import {State} from "../libraries/State.sol";
import {IAssetFactory} from "../interfaces/IAssetFactory.sol";
import {ICommon} from "../interfaces/ICommon.sol";
import {PsmLibrary} from "../libraries/PsmLib.sol";
import {IUniswapV2Factory} from "../interfaces/uniswap-v2/factory.sol";
import {RouterState} from "./flash-swaps/FlashSwapRouter.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap-v2/RouterV2.sol";
import {MutexLock} from "../libraries/MutexLock.sol";

abstract contract ModuleState is ICommon {
    using PsmLibrary for State;

    mapping(Id => State) internal states;
    address internal immutable swapAssetFactory;

    /// @dev in this case is uni v2
    address internal immutable ammFactory;

    address internal immutable dsFlashSwapRouter;

    /// @dev in this case is uni v2
    address internal immutable ammRouter;

    address internal immutable config;

    uint256 psmBaseRedemptionFeePrecentage;

    /**
     * @dev checks if caller is config contract or not
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
        address _config,
        uint256 _psmBaseRedemptionFeePrecentage
    ) {
        swapAssetFactory = _swapAssetFactory;
        ammFactory = _ammFactory;
        dsFlashSwapRouter = _dsFlashSwapRouter;
        ammRouter = _ammRouter;
        config = _config;
        psmBaseRedemptionFeePrecentage = _psmBaseRedemptionFeePrecentage;
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

    modifier onlyFlashSwapRouter() {
        if (msg.sender != dsFlashSwapRouter) {
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

    /// @notice This will revert if the contract is locked
    modifier nonReentrant() {
        if (MutexLock.isLocked()) revert StateLocked();
        MutexLock.lock();
        _;
        MutexLock.unlock();
    }
}
