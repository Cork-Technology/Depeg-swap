// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {HedgeUnit} from "./HedgeUnit.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IHedgeUnitRouter} from "../../interfaces/IHedgeUnitRouter.sol";

/**
 * @title HedgeUnitRouter
 * @notice This contract is used to execute batch mint and batch dissolve functions for multiple HedgeUnit contracts.
 */
contract HedgeUnitRouter is IHedgeUnitRouter, AccessControl, ReentrancyGuardTransient {
    // this role will be assigned through grantRole function
    bytes32 public constant HEDGE_UNIT_FACTORY_ROLE = keccak256("HEDGE_UNIT_FACTORY_ROLE");

    // Mapping to keep track of legitimate HedgeUnit contracts
    mapping(address => bool) public isHedgeUnit;

    modifier onlyDefaultAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotDefaultAdmin();
        }
        _;
    }

    modifier onlyHedgeUnitFactory() {
        if (!hasRole(HEDGE_UNIT_FACTORY_ROLE, msg.sender)) {
            revert CallerNotFactory();
        }
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Adds new HedgeUnit contract address
     * @param hedgeUnitAdd new Hedge Unit contract address
     */
    function addHedgeUnit(address hedgeUnitAdd) external onlyHedgeUnitFactory {
        if (hedgeUnitAdd == address(0)) {
            revert InvalidInput();
        }
        if (isHedgeUnit[hedgeUnitAdd]) {
            revert HedgeUnitExists();
        }
        isHedgeUnit[hedgeUnitAdd] = true;
        emit HedgeUnitSet(hedgeUnitAdd);
    }

    // This function is used to preview batch dissolve multiple HedgeUnits in single transaction.
    function previewBatchDissolve(address[] calldata hedgeUnits, uint256[] calldata amounts)
        external
        view
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts, uint256[] memory raAmounts)
    {
        if (hedgeUnits.length != amounts.length) {
            revert InvalidInput();
        }

        dsAmounts = new uint256[](hedgeUnits.length);
        paAmounts = new uint256[](hedgeUnits.length);
        raAmounts = new uint256[](hedgeUnits.length);

        for (uint256 i = 0; i < hedgeUnits.length; i++) {
            if(!isHedgeUnit[hedgeUnits[i]]) {
                revert InvalidInput();
            }
            (dsAmounts[i], paAmounts[i], raAmounts[i]) =
                HedgeUnit(hedgeUnits[i]).previewDissolve(msg.sender, amounts[i]);
        }
    }

    // This function is used to dissolve multiple HedgeUnits in single transaction.
    function batchDissolve(address[] calldata hedgeUnits, uint256[] calldata amounts)
        external
        nonReentrant
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts, uint256[] memory raAmounts)
    {
        if (hedgeUnits.length != amounts.length) {
            revert InvalidInput();
        }

        dsAmounts = new uint256[](hedgeUnits.length);
        paAmounts = new uint256[](hedgeUnits.length);
        raAmounts = new uint256[](hedgeUnits.length);

        for (uint256 i = 0; i < hedgeUnits.length; i++) {
            if(!isHedgeUnit[hedgeUnits[i]]) {
                revert InvalidInput();
            }
            (dsAmounts[i], paAmounts[i], raAmounts[i]) = HedgeUnit(hedgeUnits[i]).dissolve(msg.sender, amounts[i]);
        }
    }
}
