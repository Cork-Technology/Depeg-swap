// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

/**
 * @title Protected Unit Interface
 * @notice Defines the standard functions and events for Protected Unit tokens
 * @dev Interface for creating, managing, and redeeming Protected Unit tokens
 */
interface IProtectedUnit is IErrors {
    /// @notice Thrown when the caller is not the factory
    error OnlyFactory();

    /// @notice Thrown when upgradeability is already renounced
    error AlreadyRenounced();

    /// @notice Thrown when Permit2 permit fails
    error PermitFailed();

    /**
     * @notice Emmits when new Protected Unit tokens are created
     * @param minter The wallet address that created the tokens
     * @param amount How many tokens were created
     */
    event Mint(address indexed minter, uint256 amount);

    /**
     * @notice Emmits when Protected Unit tokens are redeemed
     * @param dissolver The wallet address that redeemed the tokens
     * @param amount How many tokens were redeemed
     * @param dsAmount How many DS tokens were received
     * @param paAmount How many PA tokens were received
     */
    event Burn(address indexed dissolver, uint256 amount, uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Emmits when the maximum supply limit changes
     * @param newMintCap The new maximum supply limit
     */
    event MintCapUpdated(uint256 newMintCap);

    /**
     * @notice Emmits when RA tokens are redeemed
     * @param redeemer The wallet address that performed the redemption
     * @param dsId The identifier of the DS token used
     * @param amount How many tokens were redeemed
     */
    event RaRedeemed(address indexed redeemer, uint256 dsId, uint256 amount);

    /**
     * @notice Gets the maximum number of tokens that can be created
     * @return The current maximum supply limit
     */
    function mintCap() external view returns (uint256);

    function pa() external view returns (address);

    function ra() external view returns (address);

    function dsReserve() external view returns (uint256);

    function paReserve() external view returns (uint256);

    function raReserve() external view returns (uint256);

    function latestDs() external view returns (address);

    /**
     * @notice Calculates how many DS and PA tokens you need to create Protected Unit tokens
     * @param amount How many Protected Unit tokens you want to create
     * @return dsAmount How many DS tokens you need
     * @return paAmount How many PA tokens you need
     */
    function previewMint(uint256 amount) external view returns (uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Creates new Protected Unit tokens by depositing DS and PA tokens
     * @param amount How many Protected Unit tokens you want to create
     * @return dsAmount How many DS tokens were used
     * @return paAmount How many PA tokens were used
     */
    function mint(uint256 amount) external returns (uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Calculates how many tokens you'll receive for redeeming Protected Unit tokens
     * @param dissolver The wallet address that will redeem the tokens
     * @param amount How many Protected Unit tokens you want to redeem
     * @return dsAmount How many DS tokens you'll receive
     * @return paAmount How many PA tokens you'll receive
     * @return raAmount How many RA tokens you'll receive
     */
    function previewBurn(address dissolver, uint256 amount)
        external
        view
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount);

    /**
     * @notice Changes the maximum number of tokens that can be created
     * @param _newMintCap The new maximum supply limit
     * @dev Only callable by the contract owner
     */
    function updateMintCap(uint256 _newMintCap) external;

    /**
     * @notice Gets the current balance of all tokens held by the contract
     * @return dsReserves How many DS tokens are in the contract
     * @return paReserves How many PA tokens are in the contract
     * @return raReserves How many RA tokens are in the contract
     */
    function getReserves() external view returns (uint256 dsReserves, uint256 paReserves, uint256 raReserves);

    /**
     * @notice Updates the contract's internal record of token balances
     * @dev Call this to ensure the contract has accurate balance information
     */
    function sync() external;
}
