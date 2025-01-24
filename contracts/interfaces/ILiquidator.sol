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

    struct CreateHedgeUnitOrderParams {
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
        address hedgeUnit;
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

    function createOrderVault(ILiquidator.CreateVaultOrderParams memory params) external;

    function finishVaultOrder(bytes32 refId) external;

    function finishHedgeUnitOrder(bytes32 refId) external;

    function fetchVaultReceiver(bytes32 refId) external returns (address receiver);

    function finishHedgeUnitOrderAndExecuteTrade(
        bytes32 refId,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external returns (uint256 amountOut);

    function createOrderHedgeUnit(ILiquidator.CreateHedgeUnitOrderParams calldata params) external;

    function fetchHedgeUnitReceiver(bytes32 refId) external returns (address receiver);
}
