pragma solidity ^0.8.24;

interface IHedgeUnit {
    // Events
    /**
     * @notice Emitted when a user mints new HedgeUnit tokens.
     * @param minter The address of the user minting the tokens.
     * @param amount The amount of HedgeUnit tokens minted.
     */
    event Mint(address indexed minter, uint256 amount);

    /**
     * @notice Emitted when a user dissolves HedgeUnit tokens.
     * @param dissolver The address of the user dissolving the tokens.
     * @param amount The amount of HedgeUnit tokens dissolved.
     * @param dsAmount The amount of DS tokens received.
     * @param paAmount The amount of PA tokens received.
     */
    event Dissolve(address indexed dissolver, uint256 amount, uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Emitted when the mint cap is updated.
     * @param newMintCap The new mint cap value.
     */
    event MintCapUpdated(uint256 newMintCap);

    event RaRedeemed(address indexed redeemer, uint256 dsId, uint256 amount);

    // Errors

    /// @notice Error indicating an invalid amount was provided.
    error InvalidAmount();

    /// @notice Error indicating the mint cap has been exceeded.
    error MintCapExceeded();

    /// @notice Error indicating an invalid value was provided.
    error InvalidValue();

    /// @notice Thrown when the DS given when minting HU isn't proportional
    error InsufficientDsAmount();

    /// @notice Thrown when the PA given when minting HU isn't proportional
    error InsufficientPaAmount();

    /// @notice Thrown when trying to overdraw HU exceeding the available liquidity
    error NotEnoughLiquidity();

    error NoValidDSExist();

    // Read functions
    /**
     * @notice Returns the current mint cap.
     * @return mintCap The maximum supply cap for minting HedgeUnit tokens.
     */
    function mintCap() external view returns (uint256);

    /**
     * @notice Returns the dsAmount and paAmount required to mint the specified amount of HedgeUnit tokens.
     * @return dsAmount The amount of DS tokens required to mint the specified amount of HedgeUnit tokens.
     * @return paAmount The amount of PA tokens required to mint the specified amount of HedgeUnit tokens.
     */
    function previewMint(uint256 amount) external view returns (uint256 dsAmount, uint256 paAmount);

    //functions
    /**
     * @notice Mints HedgeUnit tokens by transferring the equivalent amount of DS and PA tokens.
     * @param amount The amount of HedgeUnit tokens to mint.
     * @custom:reverts MintingPaused if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     * @return dsAmount The amount of DS tokens used to mint HedgeUnit tokens.
     * @return paAmount The amount of PA tokens used to mint HedgeUnit tokens.
     */
    function mint(uint256 amount) external returns (uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Returns the dsAmount and paAmount received for dissolving the specified amount of HedgeUnit tokens.
     * @return dsAmount The amount of DS tokens received for dissolving the specified amount of HedgeUnit tokens.
     * @return paAmount The amount of PA tokens received for dissolving the specified amount of HedgeUnit tokens.
     */
    function previewDissolve(uint256 amount)
        external
        view
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount);

    /**
     * @notice Dissolves HedgeUnit tokens and returns the equivalent amount of DS and PA tokens.
     * @param amount The amount of HedgeUnit tokens to dissolve.
     * @return dsAmount The amount of DS tokens returned.
     * @return paAmount The amount of PA tokens returned.
     * @custom:reverts InvalidAmount if the user has insufficient HedgeUnit balance.
     */
    function dissolve(uint256 amount) external returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount);

    /**
     * @notice Updates the mint cap.
     * @param _newMintCap The new mint cap value.
     * @custom:reverts InvalidValue if the mint cap is not changed.
     */
    function updateMintCap(uint256 _newMintCap) external;

    function getReserves() external view returns (uint256 dsReserves, uint256 paReserves, uint256 raReserves);
}
