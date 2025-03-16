// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
/**
 * @title Protected Unit Router Interface
 * @notice Defines functions for interacting with multiple Protected Units in a single transaction
 * @dev Interface for batch operations on Protected Unit tokens
 */

interface IProtectedUnitRouter is IErrors {
    /**
     * @notice Parameters needed for creating multiple Protected Unit tokens at once
     * @param protectedUnits List of Protected Unit contract addresses to mint from
     * @param amounts How many tokens to mint from each contract
     * @param permitBatchData Permission signatures for DS and PA token transfers
     * @param transferDetails Details of the token transfers
     * @param signature Signature authorizing the permits
     * @dev All arrays must be the same length
     */
    struct BatchMintParams {
        address[] protectedUnits;
        uint256[] amounts;
        IPermit2.PermitBatchTransferFrom permitBatchData;
        IPermit2.SignatureTransferDetails[] transferDetails;
        bytes signature;
    }

    /**
     * @notice Parameters needed for burning multiple Protected Unit tokens
     * @param protectedUnits List of Protected Unit contract addresses to burn from
     * @param amounts How many tokens to burn from respective Protected Unit contract
     * @param permitBatchData Permission signatures for Protected Unit token transfers
     * @param transferDetails Details of the token transfers
     * @param signature Signature authorizing the permits
     * @dev All arrays must be the same length
     */
    struct BatchBurnPermitParams {
        address[] protectedUnits;
        uint256[] amounts;
        IPermit2.PermitBatchTransferFrom permitBatchData;
        ISignatureTransfer.SignatureTransferDetails[] transferDetails;
        bytes signature;
    }

    /**
     * @notice Emmits when a new Protected Unit is added to the router
     * @param protectedUnit Address of the Protected Unit contract that was added
     */
    event ProtectedUnitSet(address protectedUnit);

    /**
     * @notice Emmits when a Protected Unit is removed from the router
     * @param protectedUnit Address of the Protected Unit contract that was removed
     */
    event ProtectedUnitRemoved(address protectedUnit);
}
