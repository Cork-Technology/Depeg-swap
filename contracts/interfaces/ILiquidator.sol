pragma solidity ^0.8.24;

/**
 * @title ILiquidator Interface
 * @author Cork Team
 * @notice Interface which provides common errors, events and functions for Liquidator contract
 */
interface ILiquidator {
    event OrderRequest(
        address indexed raToken,
        address indexed paToken,
        uint256 amount,
        uint256 minAmount,
        uint256 expiry,
        address owner,
        bytes32 orderUid
    );

    event SwapExecuted(
        uint256 indexed orderId,
        address indexed raToken,
        address indexed paToken,
        uint256 amount,
        uint256 receivedAmount,
        string status
    );

    event SwapFailed(
        address indexed raToken,
        address indexed paToken,
        uint256 amount,
        uint256 minAmount,
        uint256 expiry,
        string reason
    );
}
