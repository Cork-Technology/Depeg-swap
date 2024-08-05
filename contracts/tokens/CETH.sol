// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// CETH Contract
contract CETH is ERC20, Ownable {
    constructor() ERC20("Cork ETH", "CETH") Ownable(msg.sender){}

    // Minting function, only the owner can mint
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
