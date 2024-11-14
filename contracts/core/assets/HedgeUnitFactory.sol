// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HedgeUnit} from "./HedgeUnit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";

/**
 * @title HedgeUnitFactory
 * @notice This contract is used to deploy and manage multiple HedgeUnit contracts for different asset pairs.
 * @dev The factory contract keeps track of all deployed HedgeUnit contracts.
 */
contract HedgeUnitFactory is Ownable {
    using PairLibrary for Pair;

    uint256 internal idx;

    // Mapping to keep track of HedgeUnit contracts by a unique pair identifier
    mapping(Id => address) public hedgeUnitContracts;
    mapping(uint256 => Id) internal hedgeUnits;

    // Addresses needed for the construction of new HedgeUnit contracts
    address private moduleCore;
    address private liquidator;

    // Event emitted when a new HedgeUnit contract is deployed
    event HedgeUnitDeployed(Id indexed pairId, address indexed hedgeUnitAddress);

    error HedgeUnitExists();
    error InvalidPairId();

    /**
     * @notice Constructor sets the initial addresses for MODULE_CORE and LIQUIDATOR.
     * @param _moduleCore Address of the MODULE_CORE.
     * @param _liquidator Address of the LIQUIDATOR.
     */
    constructor(address _moduleCore, address _liquidator) Ownable(msg.sender) {
        moduleCore = _moduleCore;
        liquidator = _liquidator;
    }

    /**
     * @notice Deploys a new HedgeUnit contract for a specific asset pair.
     * @param _id Id of the pair to be managed by the HedgeUnit contract.
     * @param _PA Address of the PA token.
     * @param _pairName Name of the HedgeUnit pair.
     * @param _mintCap Initial mint cap for the HedgeUnit tokens.
     * @return newUnit of the newly deployed HedgeUnit contract.
     */
    function deployHedgeUnit(Id _id, address _PA, string memory _pairName, uint256 _mintCap)
        external
        onlyOwner
        returns (address newUnit)
    {
        if (hedgeUnitContracts[_id] != address(0)) {
            revert HedgeUnitExists();
        }

        // Deploy a new HedgeUnit contract
        HedgeUnit newHedgeUnit = new HedgeUnit(moduleCore, liquidator, _id, _PA, _pairName, _mintCap, msg.sender);
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
}
