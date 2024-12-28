// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {HedgeUnit} from "./HedgeUnit.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/**
 * @title HedgeUnitRouter
 * @notice This contract is used to execute batch mint and batch dissolve functions for multiple HedgeUnit contracts.
 */
contract HedgeUnitRouter is ReentrancyGuardTransient {
    // This error occurs when user passes invalid input to the function.
    error InvalidInput();

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
            (dsAmounts[i], paAmounts[i], raAmounts[i]) = HedgeUnit(hedgeUnits[i]).previewDissolve(msg.sender, amounts[i]);
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
            (dsAmounts[i], paAmounts[i], raAmounts[i]) = HedgeUnit(hedgeUnits[i]).dissolve(msg.sender, amounts[i]);
        }
    }
}
