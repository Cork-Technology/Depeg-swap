pragma solidity 0.8.24;

/**
 * @title IAssetFactory Interface
 * @author Cork Team
 * @notice Interface for AssetsFactory contract
 */
interface IAssetFactory {
    /// @notice limit too long when getting deployed assets
    /// @param max Max Allowed Length
    /// @param received Length of current given parameter
    error LimitTooLong(uint256 max, uint256 received);

    /// @notice error when trying to deploying a swap asset of a non existent pair
    /// @param ra Address of RA(Redemption Asset) contract
    /// @param pa Address of PA(Pegged Asset) contract
    error NotExist(address ra, address pa);

    /// @notice emitted when a new CT + DS assets is deployed
    /// @param ra Address of RA(Redemption Asset) contract
    /// @param ct Address of CT(Cover Token) contract
    /// @param ds Address of DS(Depeg Swap Token) contract
    event AssetDeployed(address indexed ra, address indexed ct, address indexed ds);

    /// @notice emitted when a new LvAsset is deployed
    /// @param ra Address of RA(Redemption Asset) contract
    /// @param pa Address of PA(Pegged Asset) contract
    /// @param lv Address of LV(Liquidity Vault) contract
    event LvAssetDeployed(address indexed ra, address indexed pa, address indexed lv);

    function getDeployedAssets(uint8 page, uint8 limit)
        external
        view
        returns (address[] memory ra, address[] memory lv);

    function isDeployed(address asset) external view returns (bool);

    function getDeployedSwapAssets(address ra, address pa, uint8 page, uint8 limit)
        external
        view
        returns (address[] memory ct, address[] memory ds);

    function deploySwapAssets(address ra, address pa, address owner, uint256 expiry, uint256 psmExchangeRate)
        external
        returns (address ct, address ds);

    function deployLv(address ra, address pa, address owner) external returns (address lv);
}
