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
     * @notice Creates a new order to liquidate assets from a vault
     * @dev Sets up a child liquidator and records order details for tracking
     * @param params The parameters for the liquidation:
     *        - sellToken: Which token to sell
     *        - sellAmount: How many tokens to sell
     *        - buyToken: Which token to buy
     *        - internalRefId: Unique identifier for tracking
     *        - orderUid: CoW Protocol order identifier
     *        - vaultId: ID of the vault being liquidated
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If requesting or transferring funds fails
     * @custom:emits OrderSubmitted with details of the created order
     */
    function createOrderVault(ILiquidator.CreateVaultOrderParams memory params) external;

    /**
     * @notice Completes a vault liquidation order
     * @dev Moves acquired funds from the child liquidator to their final destination
     * @param refId The unique identifier of the order to complete
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If the child liquidator fails to move funds
     */
    function finishVaultOrder(bytes32 refId) external;

    /**
     * @notice Completes a Protected Unit liquidation order
     * @dev Moves acquired funds from the child liquidator to their final destination
     * @param refId The unique identifier of the order to complete
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If the child liquidator fails to move funds
     */
    function finishProtectedUnitOrder(bytes32 refId) external;

    /**
     * @notice Gets the address that will receive funds from a vault liquidation
     * @dev Deterministically generates the address using the CREATE2 opcode via Clones
     * @param refId A unique reference ID for this liquidation
     * @return receiver The address where liquidated funds will be sent
     */
    function fetchVaultReceiver(bytes32 refId) external returns (address receiver);

    /**
     * @notice Completes a Protected Unit liquidation and executes a trade
     * @param refId The unique identifier of the order
     * @param amountOutMin Minimum amount of tokens to receive from the trade
     * @param params Parameters for the trade execution
     * @param offchainGuess Suggested parameters from off-chain calculations for the trade
     * @return amountOut How many tokens were received from the trade
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If moving funds from the child liquidator fails
     */
    function finishProtectedUnitOrderAndExecuteTrade(
        bytes32 refId,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external returns (uint256 amountOut);

    /**
     * @notice Creates a new order to liquidate assets from a Protected Unit
     * @dev Sets up a child liquidator and records order details for tracking
     * @param params The parameters for the liquidation:
     *        - sellToken: Which token to sell
     *        - sellAmount: How many tokens to sell
     *        - buyToken: Which token to buy
     *        - internalRefId: Unique identifier for tracking
     *        - orderUid: CoW Protocol order identifier
     *        - protectedUnit: Address of the Protected Unit
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If requesting or transferring funds fails
     * @custom:emits OrderSubmitted with details of the created order
     */
    function createOrderProtectedUnit(ILiquidator.CreateProtectedUnitOrderParams calldata params) external;

    /**
     * @notice Gets the address that will receive funds from a Protected Unit liquidation
     * @dev Deterministically generates the address using the CREATE2 opcode via Clones
     * @param refId A unique reference ID for this liquidation
     * @return receiver The address where liquidated funds will be sent
     */
    function fetchProtectedUnitReceiver(bytes32 refId) external returns (address receiver);
}
