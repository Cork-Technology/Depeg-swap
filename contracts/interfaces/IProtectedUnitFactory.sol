// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IErrors} from "./IErrors.sol";

/**
 * @title Protected Unit Factory Interface
 * @notice Defines functions for creating and managing Protected Unit contracts
 * @dev Interface for deploying and tracking Protected Unit tokens
 */
interface IProtectedUnitFactory is IErrors {
    /**
     * @notice Records when a new Protected Unit contract is created
     * @param pairId Unique identifier for the token pair
     * @param pa Address of the Protected Asset (PA) token
     * @param ra Address of the Return Asset (RA) token
     * @param protectedUnitAddress Address of the newly created Protected Unit contract
     */
    event ProtectedUnitDeployed(Id indexed pairId, address pa, address ra, address indexed protectedUnitAddress);

    /**
     * @notice Creates a new Protected Unit contract for a given token pair
     * @param _id Unique identifier for the new token pair
     * @param _pa Address of the Protected Asset token
     * @param _ra Address of the Return Asset token
     * @param _pairName Human-readable name for this token pair
     * @param _mintCap Maximum number of tokens that can be created
     * @return Address of the newly created Protected Unit contract
     * @dev Only callable by authorized addresses
     */
    function deployProtectedUnit(Id _id, address _pa, address _ra, string calldata _pairName, uint256 _mintCap)
        external
        returns (address);

    /**
     * @notice Finds the address of an existing Protected Unit contract
     * @param _id Unique identifier for the token pair
     * @return Address of the Protected Unit contract (returns zero address if not found)
     */
    function getProtectedUnitAddress(Id _id) external view returns (address);

    /**
     * @notice Gets a paginated list of all deployed Protected Unit contracts
     * @param _page Which page of results to view (starts at 0)
     * @param _limit How many results to show per page
     * @return protectedUnitsList List of Protected Unit contract addresses
     * @return idsList List of corresponding token pair IDs
     * @dev Use pagination to handle large numbers of Protected Units
     */
    function getDeployedProtectedUnits(uint8 _page, uint8 _limit)
        external
        view
        returns (address[] memory protectedUnitsList, Id[] memory idsList);

    /**
     * @notice Removes a Protected Unit from the factory's registry
     * @param _id Unique identifier for the token pair to remove
     * @dev Only callable by authorized addresses
     */
    function deRegisterProtectedUnit(Id _id) external;
}
