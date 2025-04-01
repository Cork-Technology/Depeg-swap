// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICorkHook} from "../UniV4/IMinimalHook.sol";
import {Id} from "./../../libraries/Pair.sol";
import {ModuleCore} from "./../../core/ModuleCore.sol";
import {IErrors} from "./../IErrors.sol";

/// @title ILpHelper
/// @notice Interface for the LpHelper contract that provides utility functions for liquidity token operations
interface ILpHelper is IErrors {
    /// @notice Returns the hook contract address
    /// @return The ICorkHook instance
    function hook() external view returns (ICorkHook);

    /// @notice Returns the module core contract address
    /// @return The ModuleCore instance
    function moduleCore() external view returns (ModuleCore);

    /// @notice Get reserves for a given liquidity token address
    /// @param lp The liquidity token address
    /// @return raReserve The reserve amount for the RA token
    /// @return ctReserve The reserve amount for the CT token
    function getReserve(address lp) external view returns (uint256 raReserve, uint256 ctReserve);

    /// @notice Get reserves for a given market ID using the latest dsId/epoch
    /// @param id The market ID
    /// @return raReserve The reserve amount for the RA token
    /// @return ctReserve The reserve amount for the CT token
    function getReserve(Id id) external view returns (uint256 raReserve, uint256 ctReserve);

    /// @notice Get reserves for a given market ID and dsId/epoch
    /// @param id The market ID
    /// @param dsId The dsId/epoch
    /// @return raReserve The reserve amount for the RA token
    /// @return ctReserve The reserve amount for the CT token
    function getReserve(Id id, uint256 dsId) external view returns (uint256 raReserve, uint256 ctReserve);

    /// @notice Get the liquidity token address for a given market ID using the latest dsId/epoch
    /// @param id The market ID
    /// @return liquidityToken The address of the liquidity token
    function getLpToken(Id id) external view returns (address liquidityToken);

    /// @notice Get the liquidity token address for a given market ID and dsId/epoch
    /// @param id The market ID
    /// @param dsId The dsId/epoch
    /// @return liquidityToken The address of the liquidity token
    function getLpToken(Id id, uint256 dsId) external view returns (address liquidityToken);
}
