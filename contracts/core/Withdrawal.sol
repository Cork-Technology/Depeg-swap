pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWithdrawalRouter} from "./../interfaces/IWithdrawalRouter.sol";
import {IWithdrawal} from "./../interfaces/IWithdrawal.sol";

contract Withdrawal is IWithdrawal {
    struct WithdrawalInfo {
        uint256 claimableAt;
        address owner;
        IWithdrawalRouter.Tokens[] tokens;
    }

    uint256 public constant DELAY = 3 days;

    address public vault;

    mapping(bytes32 => WithdrawalInfo) internal withdrawals;

    // unique nonces to generate withdrawal id
    mapping(address => uint256) public nonces;

    constructor(address _vault) {
        vault = _vault;
    }

    modifier onlyVault() {
        if (msg.sender != vault) {
            revert OnlyVault();
        }
        _;
    }

    modifier onlyOwner(bytes32 withdrawalId) {
        if (withdrawals[withdrawalId].owner != msg.sender) {
            revert NotOwner(withdrawals[withdrawalId].owner, msg.sender);
        }
        _;
    }

    modifier onlyWhenClaimable(bytes32 withdrawalId) {
        if (withdrawals[withdrawalId].claimableAt > block.timestamp) {
            revert NotYetClaimable(withdrawals[withdrawalId].claimableAt, block.timestamp);
        }
        _;
    }

    function getWithdrawal(bytes32 withdrawalId) external view returns (WithdrawalInfo memory) {
        return withdrawals[withdrawalId];
    }

    // the token is expected to be transferred to this contract before calling this function
    function add(address owner, IWithdrawalRouter.Tokens[] calldata tokens)
        external
        onlyVault
        returns (bytes32 withdrawalId)
    {
        uint256 claimableAt = block.timestamp + DELAY;
        uint256 nonce = nonces[owner]++;
        WithdrawalInfo memory withdrawal = WithdrawalInfo(claimableAt, owner, tokens);

        withdrawalId = keccak256(abi.encode(withdrawal, nonce));

        // copy withdrawal item 1-1 to memory
        WithdrawalInfo storage withdrawalStorageRef = withdrawals[withdrawalId];

        withdrawalStorageRef.claimableAt = claimableAt;
        withdrawalStorageRef.owner = owner;

        // copy tokens data via a loop since direct memory copy isn't supported
        for (uint256 i = 0; i < tokens.length; i++) {
            withdrawalStorageRef.tokens.push(tokens[i]);
        }

        emit WithdrawalRequested(withdrawalId, owner, claimableAt);
    }

    function claimToSelf(bytes32 withdrawalId) external onlyOwner(withdrawalId) onlyWhenClaimable(withdrawalId) {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];

        for (uint256 i = 0; i < withdrawal.tokens.length; i++) {
            IERC20(withdrawal.tokens[i].token).transfer(withdrawal.owner, withdrawal.tokens[i].amount);
        }

        delete withdrawals[withdrawalId];

        emit WithdrawalClaimed(withdrawalId, msg.sender);
    }

    function claimRouted(bytes32 withdrawalId, address router)
        external
        onlyOwner(withdrawalId)
        onlyWhenClaimable(withdrawalId)
    {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];

        //  transfer funds to router
        for (uint256 i = 0; i < withdrawal.tokens.length; i++) {
            IERC20(withdrawal.tokens[i].token).transfer(router, withdrawal.tokens[i].amount);
        }

        IWithdrawalRouter(router).route(address(this), withdrawals[withdrawalId].tokens);

        delete withdrawals[withdrawalId];

        emit WithdrawalClaimed(withdrawalId, msg.sender);
    }
}
