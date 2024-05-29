// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

contract Asset is ERC20, ERC20Permit, ERC20FlashMint, Ownable {
    uint256 public expiry;

    constructor(
        string memory prefix,
        string memory pairName,
        address _owner,
        uint256 _expiry
    )
        ERC20(
            string(abi.encodePacked(prefix, "-", pairName)),
            string(abi.encodePacked(prefix, "-", pairName))
        )
        ERC20Permit(string(abi.encodePacked(prefix, "-", pairName)))
        Ownable(_owner)
    {
        expiry = _expiry;
    }

    function isExpired() external view returns (bool) {
        return block.timestamp >= expiry;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
