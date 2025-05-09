// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title IERC7575Adapter Interface
 * @author Cork Team
 * @notice Interface for ERC7575Adapter contract
 */
interface IERC7575Adapter {
    /// @notice Error thrown when the asset is not found
    error AssetNotFound();

    /// @notice Returns the total amount of reserves.
    /// @return totalAssets The total amount of reserves.
    function totalAssets() external view returns (uint256 totalAssets);

    /// @notice Returns the amount of reserves proportional to the given shares.
    /// @param shares The amount of shares.
    /// @return assets The amount of reserves.
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
}
