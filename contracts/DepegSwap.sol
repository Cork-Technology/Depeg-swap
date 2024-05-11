// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DepegSwap is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
}
