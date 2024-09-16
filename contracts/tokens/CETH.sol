pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CETH Contract
 * @author Cork Team
 * @notice CETH contract represents Cork ETH
 */
contract CETH is ERC20, Ownable {
    constructor() ERC20("Cork ETH", "CETH") Ownable(msg.sender) {}

    /**
     * @dev Function for minting new Cork ETH(Only owners can mint)
     * @param to Address of destination wallet
     * @param amount number of ETH to be minted
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}