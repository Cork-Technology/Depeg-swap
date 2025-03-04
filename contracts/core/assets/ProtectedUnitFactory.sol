// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ProtectedUnit} from "./ProtectedUnit.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";
import {IProtectedUnitFactory} from "../../interfaces/IProtectedUnitFactory.sol";

/**
 * @title Protected Unit Factory
 * @notice A factory contract that creates and manages Protected Unit tokens
 * @dev Creates new Protected Unit contracts and keeps track of all deployed instances
 */
contract ProtectedUnitFactory is IProtectedUnitFactory {
    using PairLibrary for Pair;

    uint256 internal idx;

    // Addresses needed for the construction of new ProtectedUnit contracts
    address public immutable MODULE_CORE;
    address public immutable CONFIG;
    address public immutable ROUTER;

    // Mapping to keep track of ProtectedUnit contracts by a unique pair identifier
    mapping(Id => address) public protectedUnitContracts;
    mapping(uint256 => Id) internal protectedUnits;

    modifier onlyConfig() {
        if (msg.sender != CONFIG) {
            revert NotConfig();
        }
        _;
    }

    /**
     * @notice Sets up the factory with required contract addresses
     * @param _moduleCore Address of the core module that manages Protected Units
     * @param _config Address of the configuration contract
     * @param _flashSwapRouter Address of the router for flash swaps
     * @dev All addresses must be non-zero
     */
    constructor(address _moduleCore, address _config, address _flashSwapRouter) {
        if (_moduleCore == address(0) || _config == address(0) || _flashSwapRouter == address(0)) {
            revert ZeroAddress();
        }
        MODULE_CORE = _moduleCore;
        CONFIG = _config;
        ROUTER = _flashSwapRouter;
    }

    /**
     * @notice Gets a list of Protected Unit contracts created by this factory
     * @param _page Which page of results to view (starts at 0)
     * @param _limit How many results to show per page
     * @return protectedUnitsList List of Protected Unit contract addresses
     * @return idsList List of unique IDs for each Protected Unit
     * @dev Use pagination to handle large numbers of Protected Units
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
     * @param _id Unique identifier for the new Protected Unit
     * @param _pa Address of the Protected Asset token
     * @param _ra Address of the Return Asset token
     * @param _pairName Human-readable name for the token pair
     * @param _mintCap Maximum number of tokens that can be created
     * @return newUnit Address of the newly created Protected Unit contract
     * @dev Only callable by the configuration contract
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
            new ProtectedUnit(MODULE_CORE, _id, _pa, _ra, _pairName, _mintCap, CONFIG, ROUTER);
        newUnit = address(newProtectedUnit);

        // Store the address of the new contract
        protectedUnitContracts[_id] = newUnit;

        // solhint-disable-next-line gas-increment-by-one
        protectedUnits[idx++] = _id;

        emit ProtectedUnitDeployed(_id, _pa, _ra, newUnit);
    }

    /**
     * @notice Finds the address of an existing Protected Unit contract
     * @param _id The unique identifier of the Protected Unit to look up
     * @return The contract address of the Protected Unit (zero address if not found)
     */
    function getProtectedUnitAddress(Id _id) external view returns (address) {
        return protectedUnitContracts[_id];
    }

    /**
     * @notice Removes a Protected Unit from the factory's registry
     * @param _id The unique identifier of the Protected Unit to remove
     * @dev Only callable by the configuration contract
     */
    function deRegisterProtectedUnit(Id _id) external onlyConfig {
        delete protectedUnitContracts[_id];
    }
}
