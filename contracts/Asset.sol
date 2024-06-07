// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./interfaces/IExpiry.sol";

contract Expiry is IExpiry {
    uint256 internal timestamp;

    constructor(uint256 _expiry) {
        timestamp = _expiry;
    }

    function isExpired() external view virtual returns (bool) {
        if (timestamp == 0) {
            return false;
        }

        return block.timestamp >= timestamp;
    }

    function expiry() external view virtual returns (uint256) {
        return timestamp;
    }
}

contract Asset is ERC20Burnable, ERC20Permit, ERC20FlashMint, Ownable, Expiry {
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
        Expiry(_expiry)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
