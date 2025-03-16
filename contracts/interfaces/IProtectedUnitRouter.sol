// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
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
     * @notice Parameters needed for permission to burn Protected Unit tokens
     * @param owner The wallet that owns the tokens
     * @param spender Who is allowed to burn the tokens
     * @param value How many tokens can be burned
     * @param deadline Time until which the permission is valid
     * @param rawProtectedUnitPermitSig Digital signature authorizing the token burn
     */
    struct BatchBurnPermitParams {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        bytes rawProtectedUnitPermitSig;
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
