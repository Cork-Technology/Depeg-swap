// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {HedgeUnit} from "./HedgeUnit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";

/**
 * @title HedgeUnitFactory
 * @notice This contract is used to deploy and manage multiple HedgeUnit contracts for different asset pairs.
 * @dev The factory contract keeps track of all deployed HedgeUnit contracts.
 */
contract HedgeUnitFactory {
    using PairLibrary for Pair;

    uint256 internal idx;

    // Mapping to keep track of HedgeUnit contracts by a unique pair identifier
    mapping(Id => address) public hedgeUnitContracts;
    mapping(uint256 => Id) internal hedgeUnits;

    // Addresses needed for the construction of new HedgeUnit contracts
    address public moduleCore;
    address public config;

    // Event emitted when a new HedgeUnit contract is deployed
    event HedgeUnitDeployed(Id indexed pairId, address indexed hedgeUnitAddress);

    error HedgeUnitExists();

    error InvalidPairId();

    modifier onlyConfig() {
        // TODO: move to interface with custom errors
        require(msg.sender == config, "HedgeUnitFactory: Only config contract can call this function");
        _;
    }

    /**
     * @notice Constructor sets the initial addresses for MODULE_CORE and LIQUIDATOR.
     * @param _moduleCore Address of the MODULE_CORE.
     * @param _config Address of the config contract
     */
    constructor(address _moduleCore, address _config) {
        moduleCore = _moduleCore;
        config = _config;
    }

    /**
     * @notice Fetches a paginated list of HedgeUnits deployed by this factory.
     * @param _page Page number (starting from 0).
     * @param _limit Number of entries per page.
     * @return hedgeUnitsList List of deployed HedgeUnit addresses for the given page.
     * @return idsList List of corresponding pair IDs for the deployed HedgeUnits.
     */
    function getDeployedHedgeUnits(uint8 _page, uint8 _limit)
        external
        view
        returns (address[] memory hedgeUnitsList, Id[] memory idsList)
    {
        uint256 start = uint256(_page) * uint256(_limit);
        uint256 end = start + uint256(_limit);

        if (end > idx) {
            end = idx;
        }

        if (start >= idx) {
            return (hedgeUnitsList, idsList); // Return empty arrays if out of bounds.
        }

        uint256 arrLen = end - start;
        hedgeUnitsList = new address[](arrLen);
        idsList = new Id[](arrLen);

        for (uint256 i = start; i < end; ++i) {
            uint256 localIndex = i - start;
            Id pairId = hedgeUnits[i];
            hedgeUnitsList[localIndex] = hedgeUnitContracts[pairId];
            idsList[localIndex] = pairId;
        }
    }

    /**
     * @notice Deploys a new HedgeUnit contract for a specific asset pair.
     * @param _id Id of the pair to be managed by the HedgeUnit contract.
     * @param _pa Address of the PA token.
     * @param _pairName Name of the HedgeUnit pair.
     * @param _mintCap Initial mint cap for the HedgeUnit tokens.
     * @return newUnit of the newly deployed HedgeUnit contract.
     */
    function deployHedgeUnit(Id _id, address _pa, address _ra, string memory _pairName, uint256 _mintCap)
        external
        onlyConfig
        returns (address newUnit)
    {
        if (hedgeUnitContracts[_id] != address(0)) {
            revert HedgeUnitExists();
        }

        // Deploy a new HedgeUnit contract
        HedgeUnit newHedgeUnit = new HedgeUnit(moduleCore, _id, _pa, _ra, _pairName, _mintCap, config);
        newUnit = address(newHedgeUnit);

        // Store the address of the new contract
        hedgeUnitContracts[_id] = newUnit;
        hedgeUnits[idx++] = _id;

        emit HedgeUnitDeployed(_id, newUnit);
    }

    /**
     * @notice Returns the address of the deployed HedgeUnit contract for a given pair.
     * @param _id The unique identifier of the pair.
     * @return Address of the HedgeUnit contract.
     */
    function getHedgeUnitAddress(Id _id) external view returns (address) {
        if (hedgeUnitContracts[_id] == address(0)) {
            revert InvalidPairId();
        }
        return hedgeUnitContracts[_id];
    }

    function deRegisterHedgeUnit(Id _id) external onlyConfig {
        delete hedgeUnitContracts[_id];
    }
}
