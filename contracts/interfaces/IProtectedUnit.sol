// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

interface IProtectedUnit is IErrors {
    // Events
    /**
     * @notice Emitted when a user mints new ProtectedUnit tokens.
     * @param minter The address of the user minting the tokens.
     * @param amount The amount of ProtectedUnit tokens minted.
     */
    event Mint(address indexed minter, uint256 amount);

    /**
     * @notice Emitted when a user burns ProtectedUnit tokens.
     * @param dissolver The address of the user dissolving the tokens.
     * @param amount The amount of ProtectedUnit tokens burned.
     * @param dsAmount The amount of DS tokens received.
     * @param paAmount The amount of PA tokens received.
     */
    event Burn(address indexed dissolver, uint256 amount, uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Emitted when the mint cap is updated.
     * @param newMintCap The new mint cap value.
     */
    event MintCapUpdated(uint256 newMintCap);

    event RaRedeemed(address indexed redeemer, uint256 dsId, uint256 amount);

    // Read functions
    /**
     * @notice Returns the current mint cap.
     * @return mintCap The maximum supply cap for minting ProtectedUnit tokens.
     */
    function mintCap() external view returns (uint256);

    /**
     * @notice Returns the dsAmount and paAmount required to mint the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens required to mint the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens required to mint the specified amount of ProtectedUnit tokens.
     */
    function previewMint(uint256 amount) external view returns (uint256 dsAmount, uint256 paAmount);

    //functions
    /**
     * @notice Mints ProtectedUnit tokens by transferring the equivalent amount of DS and PA tokens.
     * @param amount The amount of ProtectedUnit tokens to mint.
     * @custom:reverts MintingPaused if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     * @return dsAmount The amount of DS tokens used to mint ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens used to mint ProtectedUnit tokens.
     */
    function mint(uint256 amount) external returns (uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Returns the dsAmount, paAmount and raAmount received for dissolving the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return raAmount The amount of RA tokens received for dissolving the specified amount of ProtectedUnit tokens.
     */
    function previewBurn(address dissolver, uint256 amount)
        external
        view
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount);

    /**
     * @notice Updates the mint cap.
     * @param _newMintCap The new mint cap value.
     * @custom:reverts InvalidValue if the mint cap is not changed.
     */
    function updateMintCap(uint256 _newMintCap) external;

    function getReserves() external view returns (uint256 dsReserves, uint256 paReserves, uint256 raReserves);

    /**
     * @notice automatically sync reserve balance
     */
    function sync() external;
}
