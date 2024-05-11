// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

contract CoverTokenContract is ERC20, ERC20Permit, ERC20FlashMint {
    constructor(
        string memory pairName
    )
        ERC20(string(abi.encodePacked("CT-", pairName)), string(abi.encodePacked("CT-", pairName)))
        ERC20Permit(string(abi.encodePacked("CT-", pairName)))
    {}

    function mint(address to, uint256 amount) internal {
        _mint(to, amount);
    }
}
