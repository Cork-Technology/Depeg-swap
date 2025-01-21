pragma solidity ^0.8.24;

import {IDsFlashSwapCore} from "./IDsFlashSwapRouter.sol";

/// @title Interface for the Hedge Unit contract for liquidation
/// @notice This contract is responsible for providing a way for liquidation contracts to request and send back funds
/// IMPORTANT :  the Hedge Unit must make sure only authorized adddress can call the functions in this interface
interface IHedgeUnitLiquidation {
    /// @notice Request funds for liquidation, will transfer the funds directly from the Hedge Unit to the liquidation contract
    /// @param amount The amount of funds to request
    /// @param token The token to request, must be either RA or PA in the contract, will fail otherwise
    /// will revert if there's not enough funds in the Hedge Unit
    /// IMPORTANT :  the Hedge Unit must make sure only whitelisted liquidation contract adddress can call this function
    function requestLiquidationFunds(uint256 amount, address token) external;

    /// @notice Receive funds from liquidation or leftover, the Hedge Unit will do a transferFrom from the liquidation contract
    /// it is important to note that the Hedge Unit will only transfer RA from the liquidation contract
    /// @param amount The amount of funds to receive
    /// @param token The token to receive, must be either RA or PA in the contract, will fail otherwise
    function receiveFunds(uint256 amount, address token) external;

    /// @notice Use funds from liquidation, the Hedge Unit will use the received funds to buy DS
    /// IMPORTANT : the Hedge Unit must make sure only the config contract can call this function, that in turns only can be called by the config contract manager
    function useFunds(
        uint256 amount,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external returns (uint256 amountOut);

    /// @notice Returns the amount of funds available for liquidation or trading
    /// @param token The token to check, must be either RA or PA in the contract, will fail otherwise
    /// it is important to note that the hedge unit doesn't make any distinction between liquidation funds and funds that are not meant for liquidation
    /// it is the liquidator job to ensure that the funds are used for liquidation is being allocated correctly
    function fundsAvailable(address token) external view returns (uint256);

    /// @notice Event emitted when a liquidation contract requests funds
    event LiquidationFundsRequested(address indexed who, address token, uint256 amount);

    /// @notice Event emitted when a liquidation contract sends funds, can be both left over funds or resulting trade funds
    event FundsReceived(address indexed who, address token, uint256 amount);

    /// @notice Event emitted when the Hedge Unit uses funds
    event FundsUsed(address indexed who, uint256 indexed dsId, uint256 raUsed, uint256 dsReceived);
}
