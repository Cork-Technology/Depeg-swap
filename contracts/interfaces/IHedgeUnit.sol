pragma solidity 0.8.24;

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

    // Errors

    /// @notice Error indicating an invalid amount was provided.
    error InvalidAmount();

    /// @notice Error indicating the mint cap has been exceeded.
    error MintCapExceeded();

    /// @notice Error indicating an invalid value was provided.
    error InvalidValue();

    // Read functions
    /**
     * @notice Returns the current mint cap.
     * @return mintCap The maximum supply cap for minting HedgeUnit tokens.
     */
    function mintCap() external view returns (uint256);

    //functions
    /**
     * @notice Mints HedgeUnit tokens by transferring the equivalent amount of DS and PA tokens.
     * @param amount The amount of HedgeUnit tokens to mint.
     * @custom:reverts MintingPaused if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     */
    function mint(uint256 amount) external;

    /**
     * @notice Dissolves HedgeUnit tokens and returns the equivalent amount of DS and PA tokens.
     * @param amount The amount of HedgeUnit tokens to dissolve.
     * @return dsAmount The amount of DS tokens returned.
     * @return paAmount The amount of PA tokens returned.
     * @custom:reverts InvalidAmount if the user has insufficient HedgeUnit balance.
     */
    function dissolve(uint256 amount) external returns (uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Updates the mint cap.
     * @param _newMintCap The new mint cap value.
     * @custom:reverts InvalidValue if the mint cap is not changed.
     */
    function updateMintCap(uint256 _newMintCap) external;
}
