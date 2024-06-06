// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ICommon {
    /// @notice psm module is not initialized, i.e thrown when interacting with uninitialized module
    error Uinitialized();

    /// @notice psm module is already initialized, i.e thrown when trying to reinitialize a module
    error AlreadyInitialized();

    /// @notice invalid asset, thrown when trying to do something with an asset not deployed with asset factory
    error InvalidAsset(address asset);
}

interface Initialize {
    function initialize(address pa, address ra, address wa) external;
}
