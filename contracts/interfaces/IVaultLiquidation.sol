pragma solidity ^0.8.24;

import "./../libraries/Pair.sol";

/// @title Interface for the VaultLiquidation contract
/// @notice This contract is responsible for providing a way for liquidation contracts to request and send back funds
/// IMPORTANT :  the vault must make sure only authorized adddress can call the functions in this interface
interface IVaultLiquidation {
    /// @notice Request funds for liquidation
    /// @param id The id of the vault
    /// @param amount The amount of funds to request
    /// will revert if there's not enough funds in the vault
    /// IMPORTANT :  the vault must make sure only whitelisted liquidation contract adddress can call this function
    function requestLiquidationFunds(Id id, uint256 amount) external;

    /// @notice Receive funds from liquidation, the vault will do a transferFrom from the liquidation contract
    /// it is important to note that the vault will only transfer RA from the liquidation contract
    /// @param id The id of the vault
    /// @param amount The amount of funds to receive
    function receiveTradeExecuctionResultFunds(Id id, uint256 amount) external;

    /// @notice Use funds from liquidation, the vault will use the received funds to provide liquidity
    /// @param id The id of the vault
    /// IMPORTANT : the vault must make sure only the config contract can call this function, that in turns only can be called by the config contract manager
    function useTradeExecutionResultFunds(Id id) external;


    /// @notice Returns the amount of funds available for liquidation
    /// @param id The id of the vault
    function liquidationFundsAvailable(Id id) external view returns (uint256);

    /// @notice Returns the amount of RA that vault has received through liquidation
    /// @param id The id of the vault
    function tradeExecutionFundsAvailable(Id id) external view returns(uint256);

    /// @notice Event emitted when a liquidation contract requests funds
    event LiquidationFundsRequested(Id indexed id, address indexed who, uint256 amount);

    /// @notice Event emitted when a liquidation contract sends funds
    event TradeExecutionResultFundsReceived(Id indexed id, address indexed who, uint256 amount);

    /// @notice Event emitted when the vault uses funds
    event TradeExecutionResultFundsUsed(Id indexed id, address indexed who, uint256 amount);
}
