// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/Pair.sol";

interface ICommon {
    /// @notice module is not initialized, i.e thrown when interacting with uninitialized module
    error Uinitialized();

    /// @notice module is already initialized, i.e thrown when trying to reinitialize a module
    error AlreadyInitialized();

    /// @notice invalid asset, thrown when trying to do something with an asset not deployed with asset factory
    error InvalidAsset(address asset);

    /// @notice Emitted when a new LV and PSM is initialized with a given pair
    /// @param id The PSM id
    /// @param pa The address of the pegged asset
    /// @param ra The address of the redemption asset
    event Initialized(Id indexed id, address indexed pa, address indexed ra);

    /// @notice Emitted when a new DS is issued for a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param expiry The expiry of the DS
    event Issued(
        Id indexed Id,
        uint256 indexed dsId,
        uint256 indexed expiry,
        address ds,
        address ct
    );
}

interface Initialize {
    function initialize(address pa, address ra, address wa) external;

    function issueNewDs(
        Id id,
        uint256 expiry,
        address ct,
        address ds
    ) external;
}
