pragma solidity ^0.8.24;

import {IWithdrawalRouter} from "./IWithdrawalRouter.sol";

interface IWithdrawal {
    function add(address owner, IWithdrawalRouter.Tokens[] calldata tokens) external returns (bytes32 withdrawalId);

    function claimToSelf(bytes32 withdrawalId) external;

    function claimRouted(bytes32 withdrawalId, address router, bytes calldata routerData) external;

    event WithdrawalRequested(bytes32 indexed withdrawalId, address indexed owner, uint256 claimableAt);

    event WithdrawalClaimed(bytes32 indexed withdrawalId, address indexed owner);

    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    error NotYetClaimable(uint256 claimableAt, uint256 blockTimestamp);

    error NotOwner(address owner, address msgSender);

    error OnlyVault();
}
