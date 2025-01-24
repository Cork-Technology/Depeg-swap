// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {HedgeUnit} from "./HedgeUnit.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";
import {IHedgeUnitFactory} from "../../interfaces/IHedgeUnitFactory.sol";

/**
 * @title HedgeUnitFactory
 * @notice This contract is used to deploy and manage multiple HedgeUnit contracts for different asset pairs.
 * @dev The factory contract keeps track of all deployed HedgeUnit contracts.
 */
contract HedgeUnitFactory is IHedgeUnitFactory {
    using PairLibrary for Pair;

    uint256 internal idx;

    // Addresses needed for the construction of new HedgeUnit contracts
    address public immutable MODULE_CORE;
    address public immutable CONFIG;
    address public immutable ROUTER;

    // Mapping to keep track of HedgeUnit contracts by a unique pair identifier
    mapping(Id => address) public hedgeUnitContracts;
    mapping(uint256 => Id) internal hedgeUnits;

    modifier onlyConfig() {
        if (msg.sender != CONFIG) {
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
        if (_moduleCore == address(0) || _config == address(0) || _flashSwapRouter == address(0)) {
            revert ZeroAddress();
        }
        MODULE_CORE = _moduleCore;
        CONFIG = _config;
        ROUTER = _flashSwapRouter;
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
    function deployHedgeUnit(Id _id, address _pa, address _ra, string calldata _pairName, uint256 _mintCap)
        external
        onlyConfig
        returns (address newUnit)
    {
        if (hedgeUnitContracts[_id] != address(0)) {
            revert HedgeUnitExists();
        }

        // Deploy a new HedgeUnit contract
        HedgeUnit newHedgeUnit = new HedgeUnit(MODULE_CORE, _id, _pa, _ra, _pairName, _mintCap, CONFIG, ROUTER);
        newUnit = address(newHedgeUnit);

        // Store the address of the new contract
        hedgeUnitContracts[_id] = newUnit;

        // solhint-disable-next-line gas-increment-by-one
        hedgeUnits[idx++] = _id;

        emit HedgeUnitDeployed(_id, _pa, _ra, newUnit);
    }

    /**
     * @notice Returns the address of the deployed HedgeUnit contract for a given pair.
     * @param _id The unique identifier of the pair.
     * @return Address of the HedgeUnit contract.
     */
    function getHedgeUnitAddress(Id _id) external view returns (address) {
        return hedgeUnitContracts[_id];
    }

    function deRegisterHedgeUnit(Id _id) external onlyConfig {
        delete hedgeUnitContracts[_id];
    }
}
