pragma solidity ^0.8.24;

import {IWithdrawalRouter} from "./IWithdrawalRouter.sol";
import {IErrors} from "./IErrors.sol";

interface IWithdrawal is IErrors {
    function add(address owner, IWithdrawalRouter.Tokens[] calldata tokens) external returns (bytes32 withdrawalId);

    function claimToSelf(bytes32 withdrawalId) external;

    function claimRouted(bytes32 withdrawalId, address router, bytes calldata routerData) external;

    event WithdrawalRequested(bytes32 indexed withdrawalId, address indexed owner, uint256 claimableAt);

    event WithdrawalClaimed(bytes32 indexed withdrawalId, address indexed owner);
}
