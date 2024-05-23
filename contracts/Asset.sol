// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

contract Asset is ERC20, ERC20Permit, ERC20FlashMint, Ownable {
    constructor(
        string memory prefix,
        string memory pairName,
        address owner
    )
        ERC20(
            string(abi.encodePacked(prefix, "-", pairName)),
            string(abi.encodePacked(prefix, "-", pairName))
        )
        ERC20Permit(string(abi.encodePacked(prefix, "-", pairName)))
        Ownable(owner)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
