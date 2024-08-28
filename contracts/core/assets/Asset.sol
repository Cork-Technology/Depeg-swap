// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IExpiry} from "../../interfaces/IExpiry.sol";
import {IRates} from "../../interfaces/IRates.sol";

/**
 * @title Contract for Adding Exchange Rate functionality
 * @author Cork Team
 * @notice Adds Exchange Rate functionality to Assets contracts
 */
contract ExchangeRate is IRates {
    uint256 internal immutable RATE;

    constructor(uint256 _rate) {
        RATE = _rate;
    }

    function exchangeRate() external view override returns (uint256) {
        return RATE;
    }
}

/**
 * @title Contract for Adding Expiry functionality to DS
 * @author Cork Team
 * @notice Adds Expiry functionality to Assets contracts
 * @dev Used for adding Expiry functionality to contracts like DS
 */
contract Expiry is IExpiry {
    uint256 internal immutable TIMESTAMP;

    constructor(uint256 _expiry) {
        if (_expiry != 0 && _expiry < block.timestamp) {
            revert Expired();
        }

        TIMESTAMP = _expiry;
    }

    function isExpired() external view virtual returns (bool) {
        if (TIMESTAMP == 0) {
            return false;
        }

        return block.timestamp >= TIMESTAMP;
    }

    function expiry() external view virtual returns (uint256) {
        return TIMESTAMP;
    }
}

/**
 * @title Assets Contract
 * @author Cork Team
 * @notice Contract for implementing assets like DS/CT etc
 */
contract Asset is ERC20Burnable, ERC20Permit, Ownable, Expiry, ExchangeRate {
    constructor(string memory prefix, string memory pairName, address _owner, uint256 _expiry, uint256 _rate)
        ExchangeRate(_rate)
        ERC20(string(abi.encodePacked(prefix, "-", pairName)), string(abi.encodePacked(prefix, "-", pairName)))
        ERC20Permit(string(abi.encodePacked(prefix, "-", pairName)))
        Ownable(_owner)
        Expiry(_expiry)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
