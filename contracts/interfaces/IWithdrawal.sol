pragma solidity ^0.8.24;

import "./IWithdrawalRouter.sol";

interface IWithdrawal {
    function add(address owner, IWithdrawalRouter.Tokens[] calldata tokens) external returns (bytes32 withdrawalId);

    function claimToSelf(bytes32 withdrawalId) external;

    function claimRouted(bytes32 withdrawalId, address router) external;

    event WithdrawalRequested(bytes32 indexed withdrawalId, address indexed owner, uint256 claimableAt);

    event WithdrawalClaimed(bytes32 indexed withdrawalId, address indexed owner);

    error NotYetClaimable(uint256 claimableAt, uint256 blockTimestamp);

    error NotOwner(address owner, address msgSender);

    error OnlyVault();
}
