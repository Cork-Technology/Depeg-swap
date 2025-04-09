// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {CTOracle} from "./CTOracle.sol";
import {ICTOracleFactory} from "./../../interfaces/ICTOracleFactory.sol";

/**
 * @title Factory contract for CT Oracles
 * @author Cork Team
 * @notice Factory contract for deploying CT Oracles contracts
 */
contract CTOracleFactory is OwnableUpgradeable, UUPSUpgradeable, ICTOracleFactory {
    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    /// @notice Mapping from CT token address to oracle address
    mapping(address => address) public ctToOracle;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the factory contract
     * @param _owner The owner of the factory contract
     */
    function initialize(address _owner) external initializer {
        if (_owner == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Upgrades the implementation of the factory contract
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @inheritdoc ICTOracleFactory
     */
    function createCTOracle(address _ctToken) external returns (address oracle) {
        if (_ctToken == address(0)) {
            revert ZeroAddress();
        }

        // TODO not sure if this is needed, need to confirm with heri wheter only 1 oracle is allowed to exist
        // Check if oracle for this CT token already exists
        if (ctToOracle[_ctToken] != address(0)) {
            revert OracleAlreadyExists();
        }

        // Deploy new oracle
        oracle = address(new CTOracle(address(this)));

        // Store the oracle address
        ctToOracle[_ctToken] = oracle;

        emit CTOracleCreated(_ctToken, oracle);
    }
}
