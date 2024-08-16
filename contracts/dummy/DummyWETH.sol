// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20,ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// dummy contract for RA and PA
contract DummyWETH is ERC20Burnable {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() ERC20("Dummy Wrapped ETH", "DWETH") {}

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        _burn(msg.sender, wad);

        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}
