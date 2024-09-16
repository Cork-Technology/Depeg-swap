pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CST Contract
 * @author Cork Team
 * @notice CST contract represents Staked Ethereum
 */
contract CST is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public ceth;
    address public admin;
    uint256 public withdrawalDelay; // Delay time in seconds

    struct WithdrawalRequest {
        uint256 amount;
        uint256 requestTime;
    }

    mapping(address => WithdrawalRequest) public requestedWithdrawals;
    address[] public pendingUsers;  // List of users with pending withdrawal requests
    mapping(address => bool) public isUserPending;  // Tracks if user is already in the pendingUsers list

    error ZeroAddressNotAllowed();

    /// @notice error thrown when passed Amount is zero
    error ZeroAmountNotAllowed();

    /// @notice error thrown when CETH Balance is not sufficient
    error InsufficientBalance();

    /// @notice error thrown when user don't have enough CST
    error InsufficientCSTBalance();

    /// @notice error thrown when total supply of CST is 0
    error ZeroCSTSupply();

    constructor(string memory name, string memory symbol, address _ceth, address _admin, uint256 _withdrawalDelay)
        ERC20(name, symbol)
        Ownable(_admin)
    {
        if (_ceth == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        ceth = IERC20(_ceth);
        admin = _admin;
        withdrawalDelay = _withdrawalDelay; // Initialize the withdrawal delay time
    }

    /**
     * @dev Deposit CETH and receive CST tokens at a 1:1 ratio
     * @param amount number of Cork ETH to be deposited and staked ETH to be minted
     */
    function deposit(uint256 amount) public {
        if (amount == 0) {
            revert ZeroAmountNotAllowed();
        }
        ceth.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    /**
     * @dev User requests withdrawal, amount is locked and a withdrawal request is recorded
     * @param amount number of Cork ETH to be requested for withdrawal
     */
    function requestWithdrawal(uint256 amount) public {
        if (amount == 0) {
            revert ZeroAmountNotAllowed();
        }
        if (amount > balanceOf(msg.sender)) {
            revert InsufficientCSTBalance();
        }

        // Record the withdrawal request with the amount and timestamp
        requestedWithdrawals[msg.sender] = WithdrawalRequest(amount, block.timestamp);

        // Add user to pendingUsers list if not already added
        if (!isUserPending[msg.sender]) {
            pendingUsers.push(msg.sender);
            isUserPending[msg.sender] = true;
        }
    }

    /**
     * @dev Processes withdrawals for all users with pending requests whose delay period has passed
     */
    function processAllWithdrawals() public {
        uint256 totalCSTSupply = totalSupply();
        if (totalCSTSupply == 0) {
            revert ZeroCSTSupply();
        }

        uint256 cethBalance = ceth.balanceOf(address(this));

        // Iterate through all users with pending withdrawals
        for (uint256 i = 0; i < pendingUsers.length; i++) {
            address user = pendingUsers[i];
            WithdrawalRequest memory request = requestedWithdrawals[user];

            // Check if the withdrawal delay has passed
            if (request.amount > 0 && block.timestamp >= request.requestTime + withdrawalDelay) {
                // Calculate the amount of CETH to withdraw based on the user's CST balance
                uint256 cethAmount = (request.amount * cethBalance) / totalCSTSupply;

                // Burn the CST tokens from the user
                _burn(user, request.amount);

                // Transfer the corresponding amount of CETH to the user
                ceth.safeTransfer(user, cethAmount);

                // Clear the withdrawal request after successful withdrawal
                delete requestedWithdrawals[user];

                // Remove the user from the pendingUsers list
                pendingUsers[i] = pendingUsers[pendingUsers.length - 1];
                pendingUsers.pop();
                isUserPending[user] = false;
                i--;  // Adjust the index after removal
            }
        }
    }

    /**
     * @dev Admin can slash CETH from the contract
     * @param amount number of ETH to be minted
     */
    function slash(uint256 amount) public onlyOwner {
        if (amount > ceth.balanceOf(address(this))) {
            revert InsufficientBalance();
        }
        ceth.safeTransfer(admin, amount);
    }
}
