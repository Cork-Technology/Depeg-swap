// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IExpiry} from "../../../contracts/interfaces/IExpiry.sol";
import {IRates} from "../../../contracts/interfaces/IRates.sol";
import {CustomERC20Permit} from "../../../contracts/libraries/ERC/CustomERC20Permit.sol";

import {KontrolTest} from "./KontrolTest.k.sol";
import "./Constants.k.sol";

/**
 * @title Contract for Adding Exchange Rate functionality
 * @author Cork Team
 * @notice Adds Exchange Rate functionality to Assets contracts
 */
abstract contract ExchangeRate is IRates {
    uint256 internal rate;

    constructor(uint256 _rate) {
        rate = _rate;
    }

    /**
     * @notice returns the current exchange rate
     */
    function exchangeRate() external view override returns (uint256) {
        return rate;
    }
}

/**
 * @title Contract for Adding Expiry functionality to DS
 * @author Cork Team
 * @notice Adds Expiry functionality to Assets contracts
 * @dev Used for adding Expiry functionality to contracts like DS
 */
abstract contract Expiry is IExpiry {
    uint256 internal EXPIRY;
    uint256 internal ISSUED_AT;

    constructor(uint256 _expiry) {
        EXPIRY = _expiry;
        ISSUED_AT = block.timestamp;
    }

    /**
     * @notice returns if contract is expired or not(if timestamp==0 then contract not having any expiry)
     */
    function isExpired() external view virtual returns (bool) {
        if (EXPIRY == 0) {
            return false;
        }

        return block.timestamp >= EXPIRY;
    }

    /**
     * @notice returns expiry timestamp of contract
     */
    function expiry() external view virtual returns (uint256) {
        return EXPIRY;
    }

    function issuedAt() external view virtual returns (uint256) {
        return ISSUED_AT;
    }
}

/**
 * @title Assets Contract
 * @author Cork Team
 * @notice Contract for implementing assets like DS/CT etc
 */
contract TestAsset is ERC20Burnable, Ownable, Expiry, ExchangeRate, KontrolTest {
    uint256 internal DS_ID;

    uint256 constant private _balancesSlot = 0;
    uint256 constant private _allowancesSlot = 1;
    uint256 constant private _totalSupplySlot = 2;

    constructor(string memory name, string memory symbol, address _owner, uint256 _expiry, uint256 _rate, uint256 _dsId)
        ExchangeRate(_rate)
        ERC20(name, symbol)
        Ownable(_owner)
        Expiry(_expiry)
    {
        kevm.symbolicStorage(address(this));
        DS_ID = _dsId;
        EXPIRY = _expiry;
        ISSUED_AT = block.timestamp;
        rate = _rate;
        //The ownerSlot of Asset is 8
        uint256 _ownerSlot = 5;
        vm.store(address(this), bytes32(_ownerSlot), bytes32(uint256(uint160(_owner))));
        uint256 totalSupply = freshUInt256Bounded(string(abi.encodePacked(name,"totalSupply")));
        vm.store(address(this), bytes32(_totalSupplySlot), bytes32(totalSupply));
    }

    /**
     * @notice mints `amount` number of tokens to `to` address
     * @param to address of receiver
     * @param amount number of tokens to be minted
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice returns expiry timestamp of contract
     */
    function dsId() external view virtual returns (uint256) {
        return DS_ID;
    }

    function updateRate(uint256 newRate) external override onlyOwner {
        rate = newRate;
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
}
