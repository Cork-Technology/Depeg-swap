// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAssetFactory {
    /// @notice limit too long when getting deployed assets
    error LimitTooLong(uint256 max, uint256 received);

    /// @notice emitted when a new CT + DS assets is deployed
    event AssetDeployed(
        address indexed wa,
        address indexed ct,
        address indexed ds
    );

    /// @notice emitted when a new WrappedAsset is deployed
    event WrappedAssetDeployed(address indexed ra, address indexed wa);

    /// @notice emitted when a new LvAsset is deployed
    event LvAssetDeployed(
        address indexed ra,
        address indexed pa,
        address indexed lv
    );

    function getDeployedWrappedAssets(
        uint8 page,
        uint8 limit
    )
        external
        view
        returns (address[] memory ra, address[] memory wa, address[] memory lv);

    function isDeployed(address asset) external view returns (bool);

    function getDeployedSwapAssets(
        address wa,
        uint8 page,
        uint8 limit
    ) external view returns (address[] memory ct, address[] memory ds);

    function deploySwapAssets(
        address ra,
        address pa,
        address wa,
        address owner,
        uint256 expiry
    ) external returns (address ct, address ds);

    function deployLv(
        address ra,
        address pa,
        address wa,
        address owner
    ) external returns (address lv);

    function deployWrappedAsset(address ra) external returns (address wa);
}
