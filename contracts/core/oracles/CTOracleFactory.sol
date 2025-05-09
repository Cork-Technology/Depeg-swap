// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {CtOracle} from "./CTOracle.sol";
import {LegacyCtOracle} from "./LegacyCTOracle.sol";
import {ICTOracleFactory} from "../../interfaces/ICTOracleFactory.sol";
import {Id} from "../../libraries/Pair.sol";

/**
 * @title Factory contract for CT Oracles
 * @author Cork Team
 * @notice Factory contract for deploying CT Oracles contracts
 */
contract CTOracleFactory is OwnableUpgradeable, UUPSUpgradeable, ICTOracleFactory {
    /// @notice Mapping from CT token address to oracle address
    mapping(address => address) public ctToOracle;

    address public moduleCore;

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the factory contract
     * @param _owner The owner of the factory contract
     */
    function initialize(address _owner, address _moduleCore) external initializer {
        if (_owner == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        moduleCore = _moduleCore;
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
        _verifyParams(_ctToken);

        // Deploy new oracle
        oracle = address(new CtOracle(moduleCore, _ctToken));

        _storeAndEmit(_ctToken, oracle);
    }

    function _verifyParams(address _ctToken) internal view {
        if (_ctToken == address(0)) {
            revert ZeroAddress();
        }

        if (ctToOracle[_ctToken] != address(0)) {
            revert OracleAlreadyExists();
        }
    }

    function _storeAndEmit(address _ctToken, address oracle) internal {
        ctToOracle[_ctToken] = oracle;

        emit CTOracleCreated(_ctToken, oracle);
    }

    function createCTOracle(address _ctToken, Id marketId) external returns (address oracle) {
        _verifyParams(_ctToken);

        // Deploy new oracle
        oracle = address(new LegacyCtOracle(moduleCore, _ctToken, marketId));

        _storeAndEmit(_ctToken, oracle);
    }
}
