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

    /**
     * @notice for getting list of deployed Assets with this factory
     * @param page page number
     * @param limit number of entries per page
     * @return ra list of deployed RA assets
     * @return lv list of deployed LV assets
     */
    function getDeployedAssets(uint8 page, uint8 limit)
        external
        view
        returns (address[] memory ra, address[] memory lv);

    /**
     * @notice for safety checks in psm core, also act as kind of like a registry
     * @param asset the address of Asset contract
     */
    function isDeployed(address asset) external view returns (bool);

    /**
     * @notice for getting list of deployed SwapAssets with this factory
     * @param ra Address of RA
     * @param pa Address of PA
     * @param page page number
     * @param limit number of entries per page
     * @return ct list of deployed CT assets
     * @return ds list of deployed DS assets
     */
    function getDeployedSwapAssets(address ra, address pa, uint8 page, uint8 limit)
        external
        view
        returns (address[] memory ct, address[] memory ds);

    /**
     * @notice deploys new Swap Assets for given RA & PA
     * @param ra Address of RA
     * @param pa Address of PA
     * @param owner Address of asset owners
     * @param expiry expiry timestamp
     * @param psmExchangeRate exchange rate for this pair
     * @return ct new CT contract address
     * @return ds new DS contract address
     */
    function deploySwapAssets(address ra, address pa, address owner, uint256 expiry, uint256 psmExchangeRate)
        external
        returns (address ct, address ds);

    /**
     * @notice deploys new LV Assets for given RA & PA
     * @param ra Address of RA
     * @param pa Address of PA
     * @param owner Address of asset owners
     * @return lv new LV contract address
     */
    function deployLv(address ra, address pa, address owner) external returns (address lv);
}
