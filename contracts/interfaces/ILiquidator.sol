pragma solidity ^0.8.24;
import  "./../libraries/Pair.sol";

/**
 * @title ILiquidator Interface
 * @author Cork Team
 * @notice Interface which provides common errors, events and functions for Liquidator contract
 */
interface ILiquidator {
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

    struct Call {
        address target;
        bytes data;
    }

    event OrderSubmitted(bytes32 indexed internalRefId, bytes orderUid, address sellToken, uint256 sellAmount, address buyToken, address liquidator);

    /// @notice thrown when the internal reference id is invalid
    error InalidRefId();

    /// @notice thrown when the caller is not the hook trampoline
    error OnlyTrampoline();

    /// @notice thrown when the caller is not the liquidator
    error OnlyLiquidator();


}
