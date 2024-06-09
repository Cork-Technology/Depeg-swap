// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "../interfaces/dev/IDevToken.sol";

// dummy contract for RA and PA
contract DummyERCWithMetadata is ERC20Burnable, IDevToken {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external override {
        _mint(to, amount);
    }

    function burnSelf(uint256 amount) external override {
        _burn(msg.sender, amount);
    }
}
