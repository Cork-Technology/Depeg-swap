pragma solidity ^0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWithdrawalRouter} from "./../interfaces/IWithdrawalRouter.sol";
import {IWithdrawal} from "./../interfaces/IWithdrawal.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Withdrawal is ReentrancyGuardTransient, IWithdrawal {
    using SafeERC20 for IERC20;

    struct WithdrawalInfo {
        uint256 claimableAt;
        address owner;
        IWithdrawalRouter.Tokens[] tokens;
    }

    uint256 public constant DELAY = 3 days;

    address public immutable VAULT;

    mapping(bytes32 => WithdrawalInfo) internal withdrawals;

    // unique nonces to generate withdrawal id
    mapping(address => uint256) public nonces;

    constructor(address _vault) {
        if (_vault == address(0)) {
            revert ZeroAddress();
        }
        VAULT = _vault;
    }

    modifier onlyVault() {
        if (msg.sender != VAULT) {
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
        WithdrawalInfo memory withdrawal = WithdrawalInfo(claimableAt, owner, tokens);

        // solhint-disable-next-line gas-increment-by-one
        withdrawalId = keccak256(abi.encode(withdrawal, nonces[owner]++));

        // copy withdrawal item 1-1 to memory
        WithdrawalInfo storage withdrawalStorageRef = withdrawals[withdrawalId];

        withdrawalStorageRef.claimableAt = claimableAt;
        withdrawalStorageRef.owner = owner;

        // copy tokens data via a loop since direct memory copy isn't supported
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            withdrawalStorageRef.tokens.push(tokens[i]);
        }

        emit WithdrawalRequested(withdrawalId, owner, claimableAt);
    }

    function claimToSelf(bytes32 withdrawalId) external nonReentrant onlyOwner(withdrawalId) onlyWhenClaimable(withdrawalId) {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];

        uint256 length = withdrawal.tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            IERC20(withdrawal.tokens[i].token).safeTransfer(withdrawal.owner, withdrawal.tokens[i].amount);
        }

        delete withdrawals[withdrawalId];

        emit WithdrawalClaimed(withdrawalId, msg.sender);
    }

    function claimRouted(bytes32 withdrawalId, address router, bytes calldata routerData)
        external
        nonReentrant
        onlyOwner(withdrawalId)
        onlyWhenClaimable(withdrawalId)
    {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];

        uint256 length = withdrawal.tokens.length;

        //  transfer funds to router
        for (uint256 i = 0; i < length; ++i) {
            IERC20(withdrawal.tokens[i].token).safeTransfer(router, withdrawal.tokens[i].amount);
        }

        IWithdrawalRouter(router).route(address(this), withdrawals[withdrawalId].tokens, routerData);

        delete withdrawals[withdrawalId];

        emit WithdrawalClaimed(withdrawalId, msg.sender);
    }
}
