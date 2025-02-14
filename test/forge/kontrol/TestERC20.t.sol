// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {KontrolTest} from "./KontrolTest.k.sol";

/**
 * @title DummyERCWithMetadata Contract
 * @author Cork Team
 * @notice Dummy contract which provides ERC20 with Metadata for RA & PA
 */
contract TestERC20 is ERC20Burnable, KontrolTest {

    uint256 constant private _balancesSlot = 0;
    uint256 constant private _allowancesSlot = 1;
    uint256 constant private _totalSupplySlot = 2;

    constructor(string memory name) ERC20(name, "TTK") {
        kevm.symbolicStorage(address(this));
        uint256 totalSupply = freshUInt256Bounded(string(abi.encodePacked(name,"totalSupply")));
        vm.store(address(this), bytes32(_totalSupplySlot), bytes32(totalSupply));
    }

    function setSymbolicBalanceOf(address account, string memory name) external {
        uint256 balance = kevm.freshUInt(32, name);
        vm.assume(balance <= totalSupply());
        bytes32 balanceAccountSlot = keccak256(abi.encode(account, _balancesSlot));
        vm.store(address(this), balanceAccountSlot, bytes32(balance));
    }

    function setSymbolicAllowance(address owner, address spender, string memory name) external {
        uint256 allowance = freshUInt256Bounded(name);
        bytes32 allowanceAccountSlot = keccak256(abi.encode(spender, keccak256(abi.encode(owner, _allowancesSlot))));
        vm.store(address(this), allowanceAccountSlot, bytes32(allowance));
    }

     /**
     * @notice mints `amount` number of tokens to `to` address
     * @param to address of receiver
     * @param amount number of tokens to be minted
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
