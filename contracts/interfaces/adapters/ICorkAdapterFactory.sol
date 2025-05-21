// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title ICorkAdapterFactory Interface
 * @author Cork Team
 * @notice Interface for CorkAdapterFactory contract
 */
interface ICorkAdapterFactory {
    /// @notice The type of adapter.
    enum AdapterType {
        NONE,
        RESERVES,
        PSM
    }

    /// @notice The parameters of the adapter.
    struct AdapterParams {
        AdapterType adapterType;
        address share;
        address asset;
    }

    /// @notice Emitted when a new adapter is created.
    /// @param adapter The address of the adapter.
    /// @param adapterType The type of adapter.
    /// @param share The address of the share token.
    event CorkAdapterCreated(address indexed adapter, AdapterType adapterType, address indexed share);
}
