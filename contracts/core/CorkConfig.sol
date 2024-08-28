pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initialize} from "../interfaces/Init.sol";
import {Id} from "../libraries/Pair.sol";

/**
 * @title Config Contract
 * @author Cork Team
 * @notice Config contract for managing configurations of Cork protocol
 */
contract CorkConfig is AccessControl, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    Initialize public moduleCore;

    /// @notice thrown when caller is not manager/Admin of Cork Protocol
    error CallerNotManager();

    /// @notice thrown when passed Invalid/Zero Address
    error InvalidAddress();

    /// @notice Emitted when a moduleCore variable set
    /// @param moduleCore Address of Modulecore contract
    event ModuleCoreSet(address moduleCore);

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

    /**
     * @dev Initialize Module Core
     */
    function initializeModuleCore(address pa, address ra, uint256 lvFee, uint256 initialDsPrice) external onlyManager {
        moduleCore.initialize(pa, ra, lvFee, initialDsPrice);
    }

    /**
     * @dev Issues new assets
     */
    function issueNewDs(Id id, uint256 expiry, uint256 exchangeRates, uint256 repurchaseFeePrecentage)
        external
        whenNotPaused
        onlyManager
    {
        moduleCore.issueNewDs(id, expiry, exchangeRates, repurchaseFeePrecentage);
    }

    /**
     * @dev Updates fee rates for psm repurchase
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePrecentage) external onlyManager {
        moduleCore.updateRepurchaseFeeRate(id, newRepurchaseFeePrecentage);
    }

    /**
     * @dev Updates earlyFeeRedemption rates
     */
    function updateEarlyRedemptionFeeRate(Id id, uint256 newEarlyRedemptionFeeRate) external onlyManager {
        moduleCore.updateEarlyRedemptionFeeRate(id, newEarlyRedemptionFeeRate);
    }

    /**
     * @dev Updates pausing status of PSM and LV pools
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
     * @dev Updates base redemption fee percentage
     */
    function updatePsmBaseRedemptionFeePrecentage(uint256 newPsmBaseRedemptionFeePrecentage) external onlyManager {
        moduleCore.updatePsmBaseRedemptionFeePrecentage(newPsmBaseRedemptionFeePrecentage);
    }

    /**
     * @dev Pause this contract
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @dev Unpause this contract
     */
    function unpause() external onlyManager {
        _unpause();
    }
}
