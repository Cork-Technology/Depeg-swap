// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initialize} from "../interfaces/Init.sol";
import "../libraries/Pair.sol";

/// @title CorkConfig - Cork Config Contract
/// @notice Handles configurations
contract CorkConfig is AccessControl, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    Initialize public moduleCore;

    error CallerNotManager();
    error InvalidAddress();

    event ModuleCoreSet(address moduleCore);

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
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
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 lvAmmWaDepositThreshold,
        uint256 lvAmmCtDepositThreshold
    ) external onlyManager {
        moduleCore.initialize(pa, ra, lvFee, lvAmmWaDepositThreshold, lvAmmCtDepositThreshold);
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
