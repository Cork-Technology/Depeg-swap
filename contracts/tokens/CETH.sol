// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CETH Contract
 * @author Cork Team
 * @notice CETH contract represents Cork ETH with role-based minting
 */
contract CETH is ERC20, AccessControl {
    // Define a new role identifier for minters
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20("Cork ETH", "CETH") {
        // Grant the contract deployer the default admin role: they can grant and revoke roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the contract deployer the minter role so they can mint initially
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    /**
     * @dev Function for minting new Cork ETH (Only accounts with MINTER_ROLE can mint)
     * @param to Address of destination wallet
     * @param amount number of CETH to be minted
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Function for burning new Cork ETH (Only accounts with Burner_ROLE can burn)
     * @param from Address of from wallet
     * @param amount number of CETH to be burned
     */
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }


    /**
     * @dev Grant MINTER_ROLE to a new account (Only admin can grant)
     * @param account Address of the new minter
     */
    function addMinter(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    /**
     * @dev Revoke MINTER_ROLE from an account (Only admin can revoke)
     * @param account Address of the minter to revoke
     */
    function removeMinter(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    /**
     * @dev Grant BURNER_ROLE to a new account (Only admin can grant)
     * @param account Address of the new burner
     */
    function addBurner(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BURNER_ROLE, account);
    }

    /**
     * @dev Revoke BURNER_ROLE from an account (Only admin can revoke)
     * @param account Address of the burner to revoke
     */
    function removeBurner(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BURNER_ROLE, account);
    }
}
