// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

/**
 * @title Protected Unit Router Interface
 * @notice Defines functions for interacting with multiple Protected Units in a single transaction
 * @dev Interface for batch operations on Protected Unit tokens
 */
interface IProtectedUnitRouter is IErrors {
    /**
     * @notice Parameters needed for creating multiple Protected Unit tokens at once
     * @param deadline Time until which the transaction remains valid
     * @param protectedUnits List of Protected Unit contract addresses to mint from
     * @param amounts How many tokens to mint from each contract
     * @param rawDsPermitSigs Permission signatures for DS token transfers
     * @param rawPaPermitSigs Permission signatures for PA token transfers
     * @dev All arrays must be the same length
     */
    struct BatchMintParams {
        uint256 deadline;
        address[] protectedUnits;
        uint256[] amounts;
        bytes[] rawDsPermitSigs;
        bytes[] rawPaPermitSigs;
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
     * @notice Records when a new Protected Unit is added to the router
     * @param protectedUnit Address of the Protected Unit contract that was added
     */
    event ProtectedUnitSet(address protectedUnit);

    /**
     * @notice Records when a Protected Unit is removed from the router
     * @param protectedUnit Address of the Protected Unit contract that was removed
     */
    event ProtectedUnitRemoved(address protectedUnit);
}
