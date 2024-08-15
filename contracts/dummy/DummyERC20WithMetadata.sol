// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20,ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// dummy contract for RA and PA
contract DummyERCWithMetadata is ERC20Burnable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burnSelf(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
