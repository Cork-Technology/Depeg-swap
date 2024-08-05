// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// CST Contract
contract CST is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public ceth;
    address public admin;

    /* ========== EVENTS ========== */
    error ZeroAddressNotAllowed();
    error ZeroAmountNotAllowed();
    error InsufficientBalance();
    error InsufficientCSTBalance();
    error ZeroCSTSupply();

    constructor(
        string memory name,
        string memory symbol,
        address _ceth,
        address _admin
    ) ERC20(name, symbol) Ownable(_admin){
        if (_ceth == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        ceth = IERC20(_ceth);
        admin = _admin;
    }

    // Deposit CETH and receive CST tokens at a 1:1 ratio
    function deposit(uint256 amount) public {
        if(amount == 0){
            revert ZeroAmountNotAllowed();
        }
        ceth.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    // User can withdraw their pro-rata share of CETH by burning CST tokens
    function withdraw(uint256 amount) public {
        if(amount == 0){
            revert ZeroAmountNotAllowed();
        }
        if(amount > balanceOf(msg.sender)){
            revert InsufficientCSTBalance(); 
        }
        uint256 totalCSTSupply = totalSupply();
        if(totalCSTSupply == 0){
            revert ZeroCSTSupply();
        }

        // Calculate the amount of CETH to withdraw based on the user's CST balance
        uint256 cethAmount = (amount * ceth.balanceOf(address(this))) / totalCSTSupply;

        // Burn the CST tokens from the sender
        _burn(msg.sender, amount);

        // Transfer the corresponding amount of CETH to the sender
        ceth.safeTransfer(msg.sender, cethAmount);
    }

    // Admin can slash CETH from the contract
    function slash(uint256 amount) public onlyOwner {
        if(amount > ceth.balanceOf(address(this))){
            revert InsufficientBalance(); 
        }
        ceth.safeTransfer(admin, amount);
    }
}
