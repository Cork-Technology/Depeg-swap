pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initialize} from "../interfaces/Init.sol";
import {Id} from "../libraries/Pair.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {Pair} from "../libraries/Pair.sol";

/**
 * @title Config Contract
 * @author Cork Team
 * @notice Config contract for managing configurations of Cork protocol
 */
contract CorkConfig is AccessControl, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    Initialize public moduleCore;
    IDsFlashSwapCore public flashSwapRouter;

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

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Sets new ModuleCore contract address
     * @param _moduleCore new moduleCore contract address
     */
    function setModuleCore(address _moduleCore) external onlyManager {
        if (_moduleCore == address(0)) {
            revert InvalidAddress();
        }
        moduleCore = Initialize(_moduleCore);
        emit ModuleCoreSet(_moduleCore);
    }

    function setFlashSwapCore(address _flashSwapRouter) external onlyManager {
        if (_flashSwapRouter == address(0)) {
            revert InvalidAddress();
        }
        flashSwapRouter = IDsFlashSwapCore(_flashSwapRouter);
        emit FlashSwapCoreSet(_flashSwapRouter);
    }

    /**
     * @dev Initialize Module Core
     * @param pa Address of PA
     * @param ra Address of RA
     * @param lvFee fees for LV
     * @param initialDsPrice initial price of DS
     */
    function initializeModuleCore(address pa, address ra, uint256 lvFee, uint256 initialDsPrice) external onlyManager {
        moduleCore.initialize(pa, ra, lvFee, initialDsPrice);
    }

    /**
     * @dev Issues new assets
     */
    function issueNewDs(
        Id id,
        uint256 expiry,
        uint256 exchangeRates,
        uint256 repurchaseFeePrecentage,
        uint256 decayDiscountRateInDays,
        // won't have effect on first issuance
        uint256 rolloverPeriodInblocks
    ) external whenNotPaused onlyManager {
        moduleCore.issueNewDs(
            id, expiry, exchangeRates, repurchaseFeePrecentage, decayDiscountRateInDays, rolloverPeriodInblocks
        );
    }

    /**
     * @notice Updates fee rates for psm repurchase
     * @param id id of PSM
     * @param newRepurchaseFeePrecentage new value of repurchase fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePrecentage) external onlyManager {
        moduleCore.updateRepurchaseFeeRate(id, newRepurchaseFeePrecentage);
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
     * @param isLVDepositPaused new value of isLVDepositPaused
     * @param isLVWithdrawalPaused new value of isLVWithdrawalPaused
     */
    function updatePoolsStatus(
        Id id,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    ) external onlyManager {
        moduleCore.updatePoolsStatus(
            id, isPSMDepositPaused, isPSMWithdrawalPaused, isLVDepositPaused, isLVWithdrawalPaused
        );
    }

    /**
     * @notice Updates base redemption fee percentage
     * @param newPsmBaseRedemptionFeePrecentage new value of fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updatePsmBaseRedemptionFeePrecentage(uint256 newPsmBaseRedemptionFeePrecentage) external onlyManager {
        moduleCore.updatePsmBaseRedemptionFeePrecentage(newPsmBaseRedemptionFeePrecentage);
    }

    function updateFlashSwapRouterDiscountInDays(Id id, uint256 newDiscountInDays) external onlyManager {
        flashSwapRouter.updateDiscountRateInDdays(id, newDiscountInDays);
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
