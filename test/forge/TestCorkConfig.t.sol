// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {CorkHook} from "Cork-Hook/CorkHook.sol";
import {IDsFlashSwapCore} from "../../contracts/interfaces/IDsFlashSwapRouter.sol";

contract CorkConfigTest is Test {
    CorkConfig private config;
    address private manager;
    address private updater;
    address private liquidationContract;
    address private user;

    function setUp() public {
        manager = address(1);
        updater = address(2);
        liquidationContract = address(3);
        user = address(4);

        // Deploy CorkConfig contract
        config = new CorkConfig();

        // Assign MANAGER_ROLE to the manager
        vm.prank(manager);
        config.grantRole(config.MANAGER_ROLE(), manager);
    }

    function testSetModuleCore() public {
        address mockModuleCore = address(5);

        // Only manager can call this function
        vm.prank(manager);
        config.setModuleCore(mockModuleCore);

        assertEq(address(config.moduleCore()), mockModuleCore);
    }

    function testSetFlashSwapCore() public {
        address mockFlashSwapRouter = address(6);

        // Only manager can call this function
        vm.prank(manager);
        config.setFlashSwapCore(mockFlashSwapRouter);

        assertEq(address(config.flashSwapRouter()), mockFlashSwapRouter);
    }

    function testSetHook() public {
        address mockHook = address(7);

        // Only manager can call this function
        vm.prank(manager);
        config.setHook(mockHook);

        assertEq(address(config.hook()), mockHook);
    }

    function testWhitelistAddress() public {
        vm.warp(0); // Set block.timestamp to 0 for deterministic testing
        vm.prank(manager);
        config.whitelist(liquidationContract);

        uint256 expectedWhitelistTimestamp = block.timestamp + config.WHITELIST_TIME_DELAY();
        assertEq(config.liquidationWhitelist(liquidationContract), expectedWhitelistTimestamp);
    }

    function testBlacklistAddress() public {
        vm.prank(manager);
        config.whitelist(liquidationContract);

        vm.prank(manager);
        config.blacklist(liquidationContract);

        assertEq(config.liquidationWhitelist(liquidationContract), 0);
    }

    function testGrantRole() public {
        // Grant RATE_UPDATERS_ROLE to the updater
        vm.prank(manager);
        config.grantRole(config.RATE_UPDATERS_ROLE(), updater);

        assertTrue(config.hasRole(config.RATE_UPDATERS_ROLE(), updater));
    }

    function testGrantLiquidatorRole() public {
        vm.prank(manager);
        config.grantLiquidatorRole(liquidationContract, user);

        bytes32 liquidatorRoleHash = config._computLiquidatorRoleHash(liquidationContract);
        assertTrue(config.hasRole(liquidatorRoleHash, user));
    }

    function testRevokeLiquidatorRole() public {
        vm.prank(manager);
        config.grantLiquidatorRole(liquidationContract, user);

        vm.prank(manager);
        config.revokeLiquidatorRole(liquidationContract, user);

        bytes32 liquidatorRoleHash = config._computLiquidatorRoleHash(liquidationContract);
        assertFalse(config.hasRole(liquidatorRoleHash, user));
    }

    function testPauseAndUnpause() public {
        vm.prank(manager);
        config.pause();
        assertTrue(config.paused());

        vm.prank(manager);
        config.unpause();
        assertFalse(config.paused());
    }

    function testOnlyManagerModifier() public {
        address unauthorized = address(9);

        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        vm.prank(unauthorized);
        config.setHook(address(10));
    }

    function testInvalidAddressReverts() public {
        vm.expectRevert(CorkConfig.InvalidAddress.selector);
        vm.prank(manager);
        config.setModuleCore(address(0));
    }
}
