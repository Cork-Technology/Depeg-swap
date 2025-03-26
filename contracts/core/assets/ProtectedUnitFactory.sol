// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ProtectedUnit} from "./ProtectedUnit.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";
import {IProtectedUnitFactory} from "../../interfaces/IProtectedUnitFactory.sol";

/**
 * @title Protected Unit Factory
 * @notice A factory contract that creates and manages Protected Unit tokens
 * @dev Creates new Protected Unit contracts and keeps track of all deployed instances.
 *      Implements access control through modifiers to restrict sensitive operations.
 * @author Cork Protocol Team
 */
contract ProtectedUnitFactory is IProtectedUnitFactory, OwnableUpgradeable, UUPSUpgradeable {
    using PairLibrary for Pair;

    /**
     * @notice Counter for tracking the number of deployed Protected Unit contracts
     * @dev Used for pagination in getDeployedProtectedUnits function
     */
    uint256 internal idx;

    // Addresses needed for the construction of new ProtectedUnit contracts
    address public moduleCore;
    address public config;
    address public router;
    address public permit2;

    /**
     * @notice Mapping of pair IDs to their corresponding Protected Unit contract addresses
     * @dev Used for direct lookup of Protected Unit contracts by their unique identifier
     */
    mapping(Id => address) public protectedUnitContracts;

    /**
     * @notice Mapping of indices to pair IDs for deployed Protected Units
     * @dev Used for pagination in getDeployedProtectedUnits function
     */
    mapping(uint256 => Id) internal protectedUnits;

    /**
     * @notice Restricts function access to the configuration contract only
     * @custom:reverts NotConfig if msg.sender is not the CONFIG address
     */
    modifier onlyConfig() {
        if (msg.sender != config) {
            revert NotConfig();
        }
        _;
    }

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice initializes protected unit factory with required contract addresses
     * @param _moduleCore Address of the ModuleCore contract
     * @param _config Address of the CorkConfig contract
     * @param _flashSwapRouter Address of the router contract for flash swaps
     * @param _permit2 Address of the Permit2 contract
     * @custom:reverts ZeroAddress if any of the input addresses is the zero address
     */
    function initialize(address _moduleCore, address _config, address _flashSwapRouter, address _permit2)
        external
        initializer
    {
        if (
            _moduleCore == address(0) || _config == address(0) || _flashSwapRouter == address(0)
                || _permit2 == address(0)
        ) {
            revert ZeroAddress();
        }

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        moduleCore = _moduleCore;
        config = _config;
        router = _flashSwapRouter;
        permit2 = _permit2;
    }

    /**
     * @notice Authorizes an upgrade to a new implementation
     * @dev Only the owner can authorize upgrades
     * @param newImplementation Address of the new implementation
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
        returns (address[] memory protectedUnitsList, Id[] memory idsList)
    {
        uint256 start = uint256(_page) * uint256(_limit);
        uint256 end = start + uint256(_limit);

        if (end > idx) {
            end = idx;
        }

        if (start >= idx) {
            return (protectedUnitsList, idsList); // Return empty arrays if out of bounds.
        }

        uint256 arrLen = end - start;
        protectedUnitsList = new address[](arrLen);
        idsList = new Id[](arrLen);

        for (uint256 i = start; i < end; ++i) {
            uint256 localIndex = i - start;
            Id pairId = protectedUnits[i];
            protectedUnitsList[localIndex] = protectedUnitContracts[pairId];
            idsList[localIndex] = pairId;
        }
    }

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
        onlyConfig
        returns (address newUnit)
    {
        if (protectedUnitContracts[_id] != address(0)) {
            revert ProtectedUnitExists();
        }

        // Deploy a new ProtectedUnit contract
        ProtectedUnit newProtectedUnit =
            new ProtectedUnit(moduleCore, _id, _pa, _ra, _pairName, _mintCap, config, router, permit2);
        newUnit = address(newProtectedUnit);

        // Store the address of the new contract
        protectedUnitContracts[_id] = newUnit;

        // solhint-disable-next-line gas-increment-by-one
        protectedUnits[idx++] = _id;

        emit ProtectedUnitDeployed(_id, _pa, _ra, newUnit);
    }

    /**
     * @notice Finds the address of an existing Protected Unit contract
     * @dev Simple lookup function to retrieve a Protected Unit contract by ID
     * @param _id The unique identifier of the Protected Unit to look up
     * @return The contract address of the Protected Unit (zero address if not found)
     */
    function getProtectedUnitAddress(Id _id) external view returns (address) {
        return protectedUnitContracts[_id];
    }

    /**
     * @notice Removes a Protected Unit from the factory's registry
     * @dev Deletes the mapping entry for a Protected Unit by its ID
     * @param _id The unique identifier of the Protected Unit to remove
     * @custom:reverts NotConfig if caller is not the CONFIG address
     */
    function deRegisterProtectedUnit(Id _id) external onlyConfig {
        delete protectedUnitContracts[_id];
    }
}
