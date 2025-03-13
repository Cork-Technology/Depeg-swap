// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IWithdrawalRouter} from "./IWithdrawalRouter.sol";
import {IErrors} from "./IErrors.sol";

interface IWithdrawal is IErrors {
    function add(address owner, IWithdrawalRouter.Tokens[] calldata tokens) external returns (bytes32 withdrawalId);

    function claimToSelf(bytes32 withdrawalId) external;

    function claimRouted(bytes32 withdrawalId, address router, bytes calldata routerData) external;

    /**
     * @notice Events emitted during withdrawals
     * @dev These will show up in transaction logs
     */

    /// @notice Emitted when someone requests a withdrawal
    /// @param withdrawalId Unique ID for tracking your withdrawal
    /// @param owner Who can claim this withdrawal
    /// @param claimableAt When the withdrawal becomes available
    event WithdrawalRequested(bytes32 indexed withdrawalId, address indexed owner, uint256 claimableAt);

    /// @notice Emitted when someone claims their withdrawal
    /// @param withdrawalId Which withdrawal was claimed
    /// @param owner Who claimed the withdrawal
    event WithdrawalClaimed(bytes32 indexed withdrawalId, address indexed owner);
}
