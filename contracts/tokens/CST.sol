pragma solidity ^0.8.24;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CETH} from "./CETH.sol";

/**
 * @title CST Contract
 * @author Cork Team
 * @notice CST contract represents Staked Ethereum
 */
contract CST is ERC20, Ownable {
    CETH public ceth;
    address public admin;
    uint256 public withdrawalDelay; // Delay time in seconds
    uint256 public yieldRate;

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    struct WithdrawalRequest {
        uint256 amount;
        uint256 requestTime;
    }

    mapping(address => Deposit[]) public userDeposits;
    mapping(address => WithdrawalRequest) public requestedWithdrawals;
    address[] public pendingUsers; // List of users with pending withdrawal requests
    mapping(address => bool) public isUserPending; // Tracks if user is already in the pendingUsers list

    error ZeroAddressNotAllowed();

    /// @notice error thrown when passed Amount is zero
    error ZeroAmountNotAllowed();

    /// @notice error thrown when CETH Balance is not sufficient
    error InsufficientBalance();

    /// @notice error thrown when user don't have enough CST
    error InsufficientCSTBalance();

    /// @notice error thrown when total supply of CST is 0
    error ZeroCSTSupply();

    /// @notice thrown when trying to set negative rate
    error NoNegativeRate();

    constructor(
        string memory name,
        string memory symbol,
        address _ceth,
        address _admin,
        uint256 _withdrawalDelay,
        uint256 _yieldRate
    ) ERC20(name, symbol) Ownable(_admin) {
        if (_ceth == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        ceth = CETH(_ceth);
        admin = _admin;
        withdrawalDelay = _withdrawalDelay; // Initialize the withdrawal delay time
        yieldRate = _yieldRate;
    }

    /**
     * @dev Deposit CETH and receive CST tokens at a 1:1 ratio
     * @param amount number of Cork ETH to be deposited and staked ETH to be minted
     */
    function deposit(uint256 amount) public {
        if (amount == 0) {
            revert ZeroAmountNotAllowed();
        }

        // Record the new deposit with the current timestamp
        userDeposits[msg.sender].push(Deposit(amount, block.timestamp));

        // Mint CST tokens in proportion to the deposit
        uint256 totalCSTSupply = totalSupply();
        uint256 cethBalance = ceth.balanceOf(address(this));

        if (totalCSTSupply == 0) {
            _mint(msg.sender, amount);
        } else {
            uint256 mintAmount = (amount * totalCSTSupply) / cethBalance;

            _mint(msg.sender, mintAmount);
        }

        IERC20(address(ceth)).transferFrom(msg.sender, address(this), amount);
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
    function processWithdrawals(uint256 usersToProcess) public {
        uint256 totalCSTSupply = totalSupply();
        if (totalCSTSupply == 0) {
            revert ZeroCSTSupply();
        }

        uint256 cethBalance = ceth.balanceOf(address(this));

        // Iterate through all users with pending withdrawals
        for (uint256 i = 0; i < usersToProcess; i++) {
            address user = pendingUsers[i];
            WithdrawalRequest memory request = requestedWithdrawals[user];

            // Check if the withdrawal delay has passed
            if (request.amount > 0 && block.timestamp >= request.requestTime + withdrawalDelay) {
                // Calculate user's proportional CETH amount
                uint256 cethAmount = (request.amount * cethBalance * 1e18) / totalCSTSupply / 1e18;

                // Burn the CST tokens from the user
                _burn(user, request.amount);

                // Transfer the corresponding amount of CETH + yield to the user
                IERC20(address(ceth)).transfer(user, cethAmount);

                // Clear the withdrawal request after successful withdrawal
                delete requestedWithdrawals[user];

                // Remove the user from the pendingUsers list
                pendingUsers[i] = pendingUsers[pendingUsers.length - 1];
                pendingUsers.pop();
                isUserPending[user] = false;

                // edge cases, will throw arithmetic underflow if not handled
                if (usersToProcess == 1) {
                    break;
                }

                i--; // Adjust the index after removal
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
        IERC20(address(ceth)).transfer(admin, amount);
    }

    function changeRate(uint256 newRate) external onlyOwner {
        // Check if the new rate is different from the current rate
        require(newRate != yieldRate, "New rate must be different");

        uint256 totalCSTSupply = totalSupply();
        uint256 cethBalance = ceth.balanceOf(address(this));

        // Calculate the total amount of CETH that would be needed based on the new rate
        uint256 totalCethNeeded = (totalCSTSupply * newRate) / 1e18;

        if (newRate > yieldRate) {
            // If the new rate is higher, calculate the additional CETH needed
            uint256 cethNeeded = totalCethNeeded > cethBalance ? totalCethNeeded - cethBalance : 0;
            if (cethNeeded > 0) {
                // If not enough CETH is in the contract, request the additional amount from the admin
                ceth.mint(address(this), cethNeeded);
            }
            // Update the yield rate
            yieldRate = newRate;
        } else {
            // If the new rate is lower, calculate the excess CETH that can be slashed or transferred
            uint256 excessCeth = cethBalance > totalCethNeeded ? cethBalance - totalCethNeeded : 0;
            if (excessCeth > 0) {
                // Transfer the excess CETH to the admin (slashing the excess)
                IERC20(address(ceth)).transfer(admin, excessCeth);
            }
            // Update the yield rate
            yieldRate = newRate;
        }
    }

    function withdrawalQueueLength() public view returns (uint256) {
        return pendingUsers.length;
    }

    function getWithdrawDelay() public view returns (uint256) {
        return withdrawalDelay;
    }

    function setWithdrawDelay(uint256 _withdrawalDelay) public onlyOwner {
        withdrawalDelay = _withdrawalDelay;
    }
}
