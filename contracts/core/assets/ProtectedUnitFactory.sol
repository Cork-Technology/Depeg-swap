// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ProtectedUnit} from "./ProtectedUnit.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";
import {IProtectedUnitFactory} from "../../interfaces/IProtectedUnitFactory.sol";

/**
 * @title ProtectedUnitFactory
 * @notice This contract is used to deploy and manage multiple ProtectedUnit contracts for different asset pairs.
 * @dev The factory contract keeps track of all deployed ProtectedUnit contracts.
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
        if(msg.sender != CONFIG){
            revert NotConfig();
        }
        _;
    }

    /**
     * @notice Constructor sets the initial addresses for moduleCore, config and flashswap router.
     * @param _moduleCore Address of the MODULE_CORE.
     * @param _config Address of the config contract
     */
    constructor(address _moduleCore, address _config, address _flashSwapRouter) {
        if(_moduleCore == address(0) || _config == address(0) || _flashSwapRouter == address(0)) {
            revert ZeroAddress();
        }
        MODULE_CORE = _moduleCore;
        CONFIG = _config;
        ROUTER = _flashSwapRouter;
    }

    /**
     * @notice Fetches a paginated list of ProtectedUnits deployed by this factory.
     * @param _page Page number (starting from 0).
     * @param _limit Number of entries per page.
     * @return protectedUnitsList List of deployed ProtectedUnit addresses for the given page.
     * @return idsList List of corresponding pair IDs for the deployed ProtectedUnits.
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
     * @notice Deploys a new ProtectedUnit contract for a specific asset pair.
     * @param _id Id of the pair to be managed by the ProtectedUnit contract.
     * @param _pa Address of the PA token.
     * @param _pairName Name of the ProtectedUnit pair.
     * @param _mintCap Initial mint cap for the ProtectedUnit tokens.
     * @return newUnit of the newly deployed ProtectedUnit contract.
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
        ProtectedUnit newProtectedUnit = new ProtectedUnit(MODULE_CORE, _id, _pa, _ra, _pairName, _mintCap, CONFIG, ROUTER);
        newUnit = address(newProtectedUnit);

        // Store the address of the new contract
        protectedUnitContracts[_id] = newUnit;

        // solhint-disable-next-line gas-increment-by-one
        protectedUnits[idx++] = _id;

        emit ProtectedUnitDeployed(_id, _pa, _ra, newUnit);
    }

    /**
     * @notice Returns the address of the deployed ProtectedUnit contract for a given pair.
     * @param _id The unique identifier of the pair.
     * @return Address of the ProtectedUnit contract.
     */
    function getProtectedUnitAddress(Id _id) external view returns (address) {
        return protectedUnitContracts[_id];
    }

    function deRegisterProtectedUnit(Id _id) external onlyConfig {
        delete protectedUnitContracts[_id];
    }
}
