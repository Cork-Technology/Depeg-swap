// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Lv is ERC20Burnable, ERC20Permit, Ownable {
    constructor(
        address ra,
        address pa,
        address owner
    )
        ERC20(
            string(abi.encodePacked("LV", ERC20(ra).name(), "-", ERC20(pa).name())),
            string(abi.encodePacked("LV", ERC20(ra).name(), "-", ERC20(pa).name()))
        )
        ERC20Permit(string(abi.encodePacked("LV", ERC20(ra).name(), "-", ERC20(pa).name())))
        Ownable(owner)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
