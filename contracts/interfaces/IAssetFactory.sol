// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IAssetFactory {
    /// @notice limit too long when getting deployed assets
    error LimitTooLong(uint256 max, uint256 received);

    /// @notice error when trying to deploying a swap asset of a non existent pair
    error NotExist(address ra, address pa);

    /// @notice emitted when a new CT + DS assets is deployed
    event AssetDeployed(address indexed ra, address indexed ct, address indexed ds);

    /// @notice emitted when a new LvAsset is deployed
    event LvAssetDeployed(address indexed ra, address indexed pa, address indexed lv);

    function getDeployedAssets(uint8 page, uint8 limit)
        external
        view
        returns (address[] memory ra, address[] memory lv);

    function isDeployed(address asset) external view returns (bool);

    function getDeployedSwapAssets(address ra, address pa,uint8 page, uint8 limit)
        external
        view
        returns (address[] memory ct, address[] memory ds);

    function deploySwapAssets(address ra, address pa, address owner, uint256 expiry, uint256 psmExchangeRate)
        external
        returns (address ct, address ds);

    function deployLv(address ra, address pa, address owner) external returns (address lv);
}
