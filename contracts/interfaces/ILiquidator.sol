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
        bytes orderUid
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

    // Liquidate RA for PA for any RA-PA pair specified in function call
    function liquidateRaForPa(address raToken, address paToken, uint256 raAmount, uint256 paAmount)
        external
        returns (bool);

    function updateLiquidatorRole(address _hedgeUnit, bool _isSet) external;
}
