// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initialize} from "../interfaces/Init.sol";
import {Id} from "../libraries/Pair.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {Pair} from "../libraries/Pair.sol";
import {ModuleCore} from "./ModuleCore.sol";
import {IVault} from "./../interfaces/IVault.sol";
import {CorkHook} from "Cork-Hook/CorkHook.sol";

/**
 * @title Config Contract
 * @author Cork Team
 * @notice Config contract for managing configurations of Cork protocol
 */
contract CorkConfig is AccessControl, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant RATE_UPDATERS_ROLE = keccak256("RATE_UPDATERS_ROLE");

    ModuleCore public moduleCore;
    IDsFlashSwapCore public flashSwapRouter;
    CorkHook public hook;

    /// @notice thrown when caller is not manager/Admin of Cork Protocol
    error CallerNotManager();

    /// @notice thrown when passed Invalid/Zero Address
    error InvalidAddress();

    /// @notice Emitted when a moduleCore variable set
    /// @param moduleCore Address of Modulecore contract
    event ModuleCoreSet(address moduleCore);

    /// @notice Emitted when a flashSwapRouter variable set
    /// @param flashSwapRouter Address of flashSwapRouter contract
    event FlashSwapCoreSet(address flashSwapRouter);

    /// @notice Emitted when a hook variable set
    /// @param hook Address of hook contract
    event HookSet(address hook);

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    modifier onlyUpdaterOrManager() {
        if (!hasRole(RATE_UPDATERS_ROLE, msg.sender) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    constructor() {
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function grantRole(bytes32 role, address account) public override onlyManager {
        _grantRole(role, account);
    }

    /**
     * @dev Sets new ModuleCore contract address
     * @param _moduleCore new moduleCore contract address
     */
    function setModuleCore(address _moduleCore) external onlyManager {
        if (_moduleCore == address(0)) {
            revert InvalidAddress();
        }
        moduleCore = ModuleCore(_moduleCore);
        emit ModuleCoreSet(_moduleCore);
    }

    function setFlashSwapCore(address _flashSwapRouter) external onlyManager {
        if (_flashSwapRouter == address(0)) {
            revert InvalidAddress();
        }
        flashSwapRouter = IDsFlashSwapCore(_flashSwapRouter);
        emit FlashSwapCoreSet(_flashSwapRouter);
    }

    function setHook(address _hook) external onlyManager {
        if (_hook == address(0)) {
            revert InvalidAddress();
        }
        hook = CorkHook(_hook);
        emit HookSet(_hook);
    }

    function updateAmmBaseFeePercentage(address ra, address ct, uint256 newBaseFeePercentage) external onlyManager {
        hook.updateBaseFeePercentage(ra, ct, newBaseFeePercentage);
    }

    /**
     * @dev Initialize Module Core
     * @param pa Address of PA
     * @param ra Address of RA
     * @param lvFee fees for LV
     * @param initialDsPrice initial price of DS
     */
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 initialDsPrice,
        uint256 _psmBaseRedemptionFeePercentage,
        uint256 expiryInterval
    ) external onlyManager {
        moduleCore.initializeModuleCore(pa, ra, lvFee, initialDsPrice, _psmBaseRedemptionFeePercentage, expiryInterval);
    }

    /**
     * @dev Issues new assets
     */
    function issueNewDs(
        Id id,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        // won't have effect on first issuance
        uint256 rolloverPeriodInblocks,
        uint256 ammLiquidationDeadline
    ) external whenNotPaused onlyManager {
        moduleCore.issueNewDs(
            id,
            exchangeRates,
            repurchaseFeePercentage,
            decayDiscountRateInDays,
            rolloverPeriodInblocks,
            ammLiquidationDeadline
        );
    }

    /**
     * @notice Updates fee rates for psm repurchase
     * @param id id of PSM
     * @param newRepurchaseFeePercentage new value of repurchase fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external onlyManager {
        moduleCore.updateRepurchaseFeeRate(id, newRepurchaseFeePercentage);
    }

    /**
     * @notice Updates earlyFeeRedemption rates
     * @param id id of PSM
     * @param newEarlyRedemptionFeeRate new value of earlyRedemptin fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateEarlyRedemptionFeeRate(Id id, uint256 newEarlyRedemptionFeeRate) external onlyManager {
        moduleCore.updateEarlyRedemptionFeeRate(id, newEarlyRedemptionFeeRate);
    }

    /**
     * @notice Updates pausing status of PSM and LV pools
     * @param id id of PSM
     * @param isPSMDepositPaused new value of isPSMDepositPaused
     * @param isPSMWithdrawalPaused new value of isPSMWithdrawalPaused
     * @param isPSMRepurchasePaused new value of isPSMRepurchasePaused
     * @param isLVDepositPaused new value of isLVDepositPaused
     * @param isLVWithdrawalPaused new value of isLVWithdrawalPaused
     */
    function updatePoolsStatus(
        Id id,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isPSMRepurchasePaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    ) external onlyManager {
        moduleCore.updatePoolsStatus(
            id,
            isPSMDepositPaused,
            isPSMWithdrawalPaused,
            isPSMRepurchasePaused,
            isLVDepositPaused,
            isLVWithdrawalPaused
        );
    }

    /**
     * @notice Updates base redemption fee percentage
     * @param newPsmBaseRedemptionFeePercentage new value of fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage)
        external
        onlyManager
    {
        moduleCore.updatePsmBaseRedemptionFeePercentage(id, newPsmBaseRedemptionFeePercentage);
    }

    function updateFlashSwapRouterDiscountInDays(Id id, uint256 newDiscountInDays) external onlyManager {
        flashSwapRouter.updateDiscountRateInDdays(id, newDiscountInDays);
    }

    function updateRouterGradualSaleStatus(Id id, bool status) external onlyManager {
        flashSwapRouter.updateGradualSaleStatus(id, status);
    }

    function updateLvStrategyCtSplitPercentage(Id id, uint256 newCtSplitPercentage) external onlyManager {
        IVault(address(moduleCore)).updateCtHeldPercentage(id, newCtSplitPercentage);
    }

    function updateReserveSellPressurePercentage(Id id, uint256 newSellPressurePercentage) external onlyManager {
        flashSwapRouter.updateReserveSellPressurePercentage(id, newSellPressurePercentage);
    }

    function updatePsmRate(Id id, uint256 newRate) external onlyUpdaterOrManager {
        moduleCore.updateRate(id, newRate);
    }

    /**
     * @notice Pause this contract
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @notice Unpause this contract
     */
    function unpause() external onlyManager {
        _unpause();
    }
}
