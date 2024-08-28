// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title DummyERCWithMetadata Contract
 * @author Cork Team
 * @notice Dummy contract which provides ERC20 with Metadata for RA & PA
 */
contract DummyERCWithMetadata is ERC20Burnable, ERC20Permit {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burnSelf(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
