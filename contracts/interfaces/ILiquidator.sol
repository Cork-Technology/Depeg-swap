pragma solidity ^0.8.24;
import  "./../libraries/Pair.sol";

/**
 * @title ILiquidator Interface
 * @author Cork Team
 * @notice Interface which provides common errors, events and functions for Liquidator contract
 */
interface ILiquidator {
    struct CreateOrderParams {
        /// the internal reference id, used to associate which order is being liquidated in the liquidation contract
        /// sinceit's impossible to add the order id in the appData directly,
        /// backend must generate a random hash to be used as internalRefId when creating the order
        /// and include
        bytes32 internalRefId;
        /// the actual cow protocol order id
        bytes orderUid;
        /// must contain the target address & data for requesting funds
        /// the target address must send funds equal to sell amount to the liquidator contract
        Call preHookCall;
        /// must contain the target address & data for sending funds
        /// the target address must APPROVE funds to the liquidator contract
        Call postHookCall;
        address sellToken;
        uint256 sellAmount;
        address buyToken;
    }

    struct Call {
        address target;
        bytes data;
    }

    event OrderSubmitted(bytes32 indexed internalRefId, bytes orderUid, address sellToken, uint256 sellAmount, address buyToken);

    /// @notice thrown when the internal reference id is invalid
    error InalidRefId();

    function createOrder(ILiquidator.CreateOrderParams memory params, uint32 expiryPeriodInSecods) external;

    function encodePreHookCallData(bytes32 refId) external returns (bytes memory data);

    function encodePostHookCallData(bytes32 refId) external returns (bytes memory data);

    function encodeVaultPostHook(Id vaultId) external returns (bytes memory data);
}
