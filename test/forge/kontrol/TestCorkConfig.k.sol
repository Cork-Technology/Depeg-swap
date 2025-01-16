pragma solidity ^0.8.24;

import "../../../contracts/core/CorkConfig.sol";

import "forge-std/Test.sol";
import {KontrolCheats} from "lib/kontrol-cheatcodes/src/KontrolCheats.sol";

/// @title TestFlashSwapRouter Contract, used for testing FlashSwapRouter contract, mostly here for getter functions
contract TestCorkConfig is CorkConfig, Test, KontrolCheats {
    
    constructor() CorkConfig() {
        kevm.symbolicStorage(address(this));

        // _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        /* This role has been removed:
        bytes32 hasAdminRoleSlot = keccak256(abi.encode(msg.sender, keccak256(abi.encode(DEFAULT_ADMIN_ROLE, uint256(0)))));
        vm.store(address(this), hasAdminRoleSlot, bytes32(uint256(1)));
        */

        // _grantRole(MANAGER_ROLE, msg.sender);
        bytes32 hasManagerRoleSlot = keccak256(abi.encode(msg.sender, keccak256(abi.encode(MANAGER_ROLE, uint256(0)))));
        vm.store(address(this), hasManagerRoleSlot, bytes32(uint256(1)));
    }
}