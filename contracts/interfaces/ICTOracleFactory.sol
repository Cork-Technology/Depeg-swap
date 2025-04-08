// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title ICTOracleFactory Interface
 * @author Cork Team
 * @notice Interface which provides common errors, events and functions for CT Oracle Factory contract
 */
interface ICTOracleFactory {
    /// @notice Event emitted when a new CT Oracle is created
    event CTOracleCreated(address indexed ctToken, address indexed oracle);

    /// @notice Error indicating the CT token address is zero
    error ZeroAddress();

    /// @notice Error indicating the CT Oracle already exists
    error OracleAlreadyExists();

    /**
     * @notice Creates a new CT Oracle for a CT token
     * @param _ctToken The address of the CT token
     * @return oracle The address of the created CT Oracle
     */
    function createCTOracle(address _ctToken) external returns (address oracle);
}
