// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "./../libraries/Pair.sol";
import {IErrors} from "./IErrors.sol";
import {IDsFlashSwapCore} from "./IDsFlashSwapRouter.sol";

/**
 * @title ILiquidator Interface
 * @author Cork Team
 * @notice Interface which provides common errors, events and functions for Liquidator contract
 */
interface ILiquidator is IErrors {
    struct CreateVaultOrderParams {
        /// the internal reference id, used to associate which order is being liquidated in the liquidation contract
        /// sinceit's impossible to add the order id in the appData directly,
        /// backend must generate a random hash to be used as internalRefId when creating the order
        /// and include
        bytes32 internalRefId;
        /// the actual cow protocol order id
        bytes orderUid;
        address sellToken;
        uint256 sellAmount;
        address buyToken;
        Id vaultId;
    }

    struct CreateProtectedUnitOrderParams {
        /// the internal reference id, used to associate which order is being liquidated in the liquidation contract
        /// sinceit's impossible to add the order id in the appData directly,
        /// backend must generate a random hash to be used as internalRefId when creating the order
        /// and include
        bytes32 internalRefId;
        /// the actual cow protocol order id
        bytes orderUid;
        address sellToken;
        uint256 sellAmount;
        address buyToken;
        address protectedUnit;
    }

    struct Call {
        address target;
        bytes data;
    }

    event OrderSubmitted(
        bytes32 indexed internalRefId,
        address indexed owner,
        bytes indexed orderUid,
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        address liquidator
    );

    /**
     * @notice Creates a new liquidation order for a vault
     * @dev Initiates the process of liquidating assets from a vault through CoW Protocol
     * @param params All necessary parameters for creating the vault liquidation order
     */
    function createOrderVault(ILiquidator.CreateVaultOrderParams memory params) external;

    /**
     * @notice Completes a vault liquidation order
     * @dev Finalizes the liquidation process and transfers resulting assets
     * @param refId The reference ID of the order to complete
     */
    function finishVaultOrder(bytes32 refId) external;

    /**
     * @notice Completes a Protected Unit liquidation order
     * @dev Finalizes the liquidation process for Protected Unit assets
     * @param refId The reference ID of the order to complete
     */
    function finishProtectedUnitOrder(bytes32 refId) external;

    /**
     * @notice Gets the address that will receive vault liquidation proceeds
     * @param refId The reference ID used to determine the receiver address
     * @return receiver The address that will receive the liquidated assets
     */
    function fetchVaultReceiver(bytes32 refId) external returns (address receiver);

    /**
     * @notice Completes a Protected Unit liquidation and executes a trade
     * @param refId The reference ID of the order to complete
     * @param amountOutMin Minimum amount of tokens to receive from the trade
     * @param params Parameters for the trade execution
     * @param offchainGuess Suggested parameters from off-chain calculations
     * @return amountOut The actual amount of tokens received from the trade
     */
    function finishProtectedUnitOrderAndExecuteTrade(
        bytes32 refId,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external returns (uint256 amountOut);

    /**
     * @notice Creates a new liquidation order for a Protected Unit
     * @param params All necessary parameters for creating the Protected Unit liquidation order
     */
    function createOrderProtectedUnit(ILiquidator.CreateProtectedUnitOrderParams calldata params) external;

    /**
     * @notice Gets the address that will receive Protected Unit liquidation proceeds
     * @param refId The reference ID used to determine the receiver address
     * @return receiver The address that will receive the liquidated assets
     */
    function fetchProtectedUnitReceiver(bytes32 refId) external returns (address receiver);
}
