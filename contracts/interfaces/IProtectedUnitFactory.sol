// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IErrors} from "./IErrors.sol";

/**
 * @title Protected Unit Factory Interface
 * @notice Defines functions for creating and managing Protected Unit contracts
 * @dev Interface for deploying and tracking Protected Unit tokens
 * @author Cork Protocol Team
 */
interface IProtectedUnitFactory is IErrors {
    /// @notice Emmits when the implementation contract address is updated
    event ProtectedUnitImplUpdated(address indexed oldImpl, address indexed newImpl);

    /// @notice Emmits when a Protected Unit contract is upgraded
    event ProtectedUnitUpgraded(address indexed protectedUnit);

    /// @notice Emmits when a Protected Unit contract's upgradeability is renounced
    event RenouncedUpgradeability(address indexed protectedUnit);

    /**
     * @notice Emmits when a new Protected Unit contract is created
     * @param pairId Unique identifier for the token pair
     * @param pa Address of the Protected Asset (PA) token
     * @param ra Address of the Return Asset (RA) token
     * @param protectedUnitAddress Address of the newly created Protected Unit contract
     */
    event ProtectedUnitDeployed(Id indexed pairId, address pa, address ra, address indexed protectedUnitAddress);

    /**
     * @notice Creates a new Protected Unit contract
     * @dev Deploys a new ProtectedUnit and registers it in the factory's mappings
     * @param _id Unique Market/PSM/Vault ID from the ModuleCore contract
     * @param _pa Address of the Protected Asset token
     * @param _ra Address of the Return Asset token
     * @param _pairName Human-readable name for the token pair
     * @param _mintCap Maximum number of tokens that can be created
     * @return newUnit Address of the newly deployed Protected Unit contract
     * @custom:reverts ProtectedUnitExists if a Protected Unit with this ID already exists
     * @custom:reverts NotConfig if caller is not the CONFIG contract address
     * @custom:emits ProtectedUnitDeployed when a new contract is successfully deployed
     */
    function deployProtectedUnit(Id _id, address _pa, address _ra, string calldata _pairName, uint256 _mintCap)
        external
        returns (address);

    /**
     * @notice Finds the address of an existing Protected Unit contract
     * @dev Simple lookup function to retrieve a Protected Unit contract by ID
     * @param _id The unique identifier of the Protected Unit to look up
     * @return The contract address of the Protected Unit (zero address if not found)
     */
    function getProtectedUnitAddress(Id _id) external view returns (address);

    /**
     * @notice Gets a list of Protected Unit contracts created by this factory
     * @dev Uses pagination to handle large numbers of Protected Units efficiently
     * @param _page Which page of results to view (starts at 0)
     * @param _limit How many results to show per page
     * @return protectedUnitsList List of Protected Unit contract addresses for the requested page
     * @return idsList List of unique IDs for each Protected Unit in the response
     */
    function getDeployedProtectedUnits(uint8 _page, uint8 _limit)
        external
        view
        returns (address[] memory protectedUnitsList, Id[] memory idsList);

    /**
     * @notice Removes a Protected Unit from the factory's registry
     * @dev Deletes the mapping entry for a Protected Unit by its ID
     * @param _id The unique identifier of the Protected Unit to remove
     * @custom:reverts NotConfig if caller is not the CONFIG address
     */
    function deRegisterProtectedUnit(Id _id) external;
}
