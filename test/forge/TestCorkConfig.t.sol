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

    // events
    event ModuleCoreSet(address moduleCore);
    event FlashSwapCoreSet(address flashSwapRouter);
    event HookSet(address hook);
    event HedgeUnitFactorySet(address hedgeUnitFactory);
    event TreasurySet(address treasury);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        manager = address(1);
        updater = address(2);
        liquidationContract = address(3);
        user = address(4);

        vm.startPrank(manager);
        config = new CorkConfig(manager, manager);
        vm.stopPrank();
    }

    function test_SetModuleCoreRevertWhenCalledByNonManager() public {
        address mockModuleCore = address(5);
        vm.startPrank(address(8));

        assertEq(address(config.moduleCore()), address(0));
        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.setModuleCore(mockModuleCore);
        assertEq(address(config.moduleCore()), address(0));
    }

    function test_SetModuleCoreRevertWhenPassedZeroAddress() public {
        vm.startPrank(manager);
        assertEq(address(config.moduleCore()), address(0));
        vm.expectRevert(CorkConfig.InvalidAddress.selector);
        config.setModuleCore(address(0));
        assertEq(address(config.moduleCore()), address(0));
    }

    function test_SetModuleCoreShouldWorkCorrectly() public {
        address mockModuleCore = address(5);
        vm.startPrank(manager);
        assertEq(address(config.moduleCore()), address(0));

        vm.expectEmit(false, false, false, true);
        emit ModuleCoreSet(mockModuleCore);
        config.setModuleCore(mockModuleCore);
        assertEq(address(config.moduleCore()), mockModuleCore);
    }

    function test_SetFlashSwapCoreRevertWhenCalledByNonManager() public {
        address mockFlashSwapRouter = address(5);
        vm.startPrank(address(8));

        assertEq(address(config.flashSwapRouter()), address(0));
        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.setFlashSwapCore(mockFlashSwapRouter);
        assertEq(address(config.flashSwapRouter()), address(0));
    }

    function test_SetFlashSwapCoreRevertWhenPassedZeroAddress() public {
        vm.startPrank(manager);
        assertEq(address(config.flashSwapRouter()), address(0));
        vm.expectRevert(CorkConfig.InvalidAddress.selector);
        config.setFlashSwapCore(address(0));
        assertEq(address(config.flashSwapRouter()), address(0));
    }

    function test_SetFlashSwapCoreShouldWorkCorrectly() public {
        address mockFlashSwapRouter = address(5);
        vm.startPrank(manager);
        assertEq(address(config.flashSwapRouter()), address(0));

        vm.expectEmit(false, false, false, true);
        emit FlashSwapCoreSet(mockFlashSwapRouter);
        config.setFlashSwapCore(mockFlashSwapRouter);
        assertEq(address(config.flashSwapRouter()), mockFlashSwapRouter);
    }

    function test_SetHookRevertWhenCalledByNonManager() public {
        address mockHook = address(5);
        vm.startPrank(address(8));

        assertEq(address(config.hook()), address(0));
        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.setHook(mockHook);
        assertEq(address(config.hook()), address(0));
    }

    function test_SetHookRevertWhenPassedZeroAddress() public {
        vm.startPrank(manager);
        assertEq(address(config.hook()), address(0));
        vm.expectRevert(CorkConfig.InvalidAddress.selector);
        config.setHook(address(0));
        assertEq(address(config.hook()), address(0));
    }

    function test_SetHookShouldWorkCorrectly() public {
        address mockHook = address(5);
        vm.startPrank(manager);
        assertEq(address(config.hook()), address(0));

        vm.expectEmit(false, false, false, true);
        emit HookSet(mockHook);
        config.setHook(mockHook);
        assertEq(address(config.hook()), mockHook);
    }

    function test_SetHedgeUnitFactoryRevertWhenCalledByNonManager() public {
        address mockHedgeUnitFactory = address(5);
        vm.startPrank(address(8));

        assertEq(address(config.hedgeUnitFactory()), address(0));
        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.setHedgeUnitFactory(mockHedgeUnitFactory);
        assertEq(address(config.hedgeUnitFactory()), address(0));
    }

    function test_SetHedgeUnitFactoryRevertWhenPassedZeroAddress() public {
        vm.startPrank(manager);
        assertEq(address(config.hedgeUnitFactory()), address(0));
        vm.expectRevert(CorkConfig.InvalidAddress.selector);
        config.setHedgeUnitFactory(address(0));
        assertEq(address(config.hedgeUnitFactory()), address(0));
    }

    function test_SetHedgeUnitFactoryShouldWorkCorrectly() public {
        address mockHedgeUnitFactory = address(5);
        vm.startPrank(manager);
        assertEq(address(config.hedgeUnitFactory()), address(0));

        vm.expectEmit(false, false, false, true);
        emit HedgeUnitFactorySet(mockHedgeUnitFactory);
        config.setHedgeUnitFactory(mockHedgeUnitFactory);
        assertEq(address(config.hedgeUnitFactory()), mockHedgeUnitFactory);
    }

    function test_SetTreasuryRevertWhenCalledByNonManager() public {
        address mockTreasury = address(5);
        vm.startPrank(address(8));

        assertEq(address(config.treasury()), address(0));
        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.setTreasury(mockTreasury);
        assertEq(address(config.treasury()), address(0));
    }

    function test_SetTreasuryRevertWhenPassedZeroAddress() public {
        vm.startPrank(manager);
        assertEq(address(config.treasury()), address(0));
        vm.expectRevert(CorkConfig.InvalidAddress.selector);
        config.setTreasury(address(0));
        assertEq(address(config.treasury()), address(0));
    }

    function test_SetTreasuryShouldWorkCorrectly() public {
        address mockTreasury = address(5);
        vm.startPrank(manager);
        assertEq(address(config.treasury()), address(0));

        vm.expectEmit(false, false, false, true);
        emit TreasurySet(mockTreasury);
        config.setTreasury(mockTreasury);
        assertEq(address(config.treasury()), mockTreasury);
    }

    function test_WhitelistAddressShouldRevertWhenCalledByNonManager() public {
        uint256 expectedWhitelistTimestamp = block.timestamp + config.WHITELIST_TIME_DELAY();
        vm.startPrank(address(8));
        assertEq(config.isLiquidationWhitelisted(liquidationContract), false);

        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.whitelist(liquidationContract);
        vm.warp(expectedWhitelistTimestamp);
        assertEq(config.isLiquidationWhitelisted(liquidationContract), false);
    }

    function test_WhitelistAddressShouldWorkCorrectly() public {
        assertEq(config.isLiquidationWhitelisted(liquidationContract), false);

        vm.startPrank(manager);
        uint256 expectedWhitelistTimestamp = block.timestamp + config.WHITELIST_TIME_DELAY();
        config.whitelist(liquidationContract);

        assertEq(config.isLiquidationWhitelisted(liquidationContract), false);

        vm.warp(expectedWhitelistTimestamp);
        assertEq(config.isLiquidationWhitelisted(liquidationContract), true);
    }

    function test_BlacklistAddressShouldRevertWhenCalledByNonManager() public {
        uint256 expectedWhitelistTimestamp = block.timestamp + config.WHITELIST_TIME_DELAY();
        vm.startPrank(manager);
        config.whitelist(liquidationContract);
        vm.warp(expectedWhitelistTimestamp);
        assertEq(config.isLiquidationWhitelisted(liquidationContract), true);

        vm.startPrank(address(8));
        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.blacklist(liquidationContract);
        assertEq(config.isLiquidationWhitelisted(liquidationContract), true);
    }

    function test_BlacklistAddressShouldWorkCorrectly() public {
        assertEq(config.isLiquidationWhitelisted(liquidationContract), false);

        vm.startPrank(manager);
        uint256 expectedWhitelistTimestamp = block.timestamp + config.WHITELIST_TIME_DELAY();
        config.whitelist(liquidationContract);

        vm.warp(expectedWhitelistTimestamp);
        assertEq(config.isLiquidationWhitelisted(liquidationContract), true);

        config.blacklist(liquidationContract);
        assertEq(config.isLiquidationWhitelisted(liquidationContract), false);
    }

    function test_GrantRoleRevertWhenCalledByNonManager() public {
        bytes32 role = config.RATE_UPDATERS_ROLE();
        vm.startPrank(address(8));
        assertFalse(config.hasRole(role, updater));

        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.grantRole(role, updater);
        assertFalse(config.hasRole(role, updater));
    }

    function test_GrantRoleShouldWorkCorrectly() public {
        bytes32 role = config.RATE_UPDATERS_ROLE();
        vm.startPrank(manager);
        assertFalse(config.hasRole(role, updater));

        vm.expectEmit(false, false, false, true);
        emit RoleGranted(role, updater, manager);
        config.grantRole(role, updater);
        assertTrue(config.hasRole(role, updater));
    }

    function test_GrantLiquidatorRoleRevertWhenCalledByNonManager() public {
        bytes32 role = config._computLiquidatorRoleHash(liquidationContract);
        vm.startPrank(address(8));
        assertFalse(config.hasRole(role, updater));

        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.grantLiquidatorRole(liquidationContract, updater);
        assertFalse(config.hasRole(role, updater));
    }

    function test_GrantLiquidatorRoleShouldWorkCorrectly() public {
        bytes32 role = config._computLiquidatorRoleHash(liquidationContract);
        vm.startPrank(manager);
        assertFalse(config.hasRole(role, updater));

        vm.expectEmit(false, false, false, true);
        emit RoleGranted(role, updater, manager);
        config.grantLiquidatorRole(liquidationContract, updater);
        assertTrue(config.hasRole(role, updater));
    }

    function test_RevokeLiquidatorRoleRevertWhenCalledByNonManager() public {
        bytes32 role = config._computLiquidatorRoleHash(liquidationContract);
        vm.startPrank(address(8));
        assertFalse(config.hasRole(role, updater));

        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.revokeLiquidatorRole(liquidationContract, updater);
        assertFalse(config.hasRole(role, updater));
    }

    function test_RevokeLiquidatorRoleShouldWorkCorrectly() public {
        bytes32 role = config._computLiquidatorRoleHash(liquidationContract);

        vm.startPrank(manager);
        config.grantLiquidatorRole(liquidationContract, updater);

        vm.startPrank(manager);
        assertTrue(config.hasRole(role, updater));

        vm.expectEmit(false, false, false, true);
        emit RoleRevoked(role, updater, manager);
        config.revokeLiquidatorRole(liquidationContract, updater);
        assertFalse(config.hasRole(role, updater));
    }

    function test_PauseShouldRevertWhenCalledByNonManager() public {
        vm.startPrank(address(8));
        assertFalse(config.paused());

        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.pause();
        assertFalse(config.paused());
    }

    function test_PauseShouldWorkCorrectly() public {
        vm.startPrank(manager);
        assertFalse(config.paused());

        vm.expectEmit(false, false, false, true);
        emit Paused(manager);
        config.pause();
        assertTrue(config.paused());
    }

    function test_UnpauseShouldRevertWhenCalledByNonManager() public {
        vm.startPrank(manager);
        config.pause();
        assertTrue(config.paused());

        vm.startPrank(address(8));
        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        config.unpause();
        assertTrue(config.paused());
    }

    function test_UnpauseShouldWorkCorrectly() public {
        vm.startPrank(manager);
        config.pause();
        assertTrue(config.paused());

        vm.expectEmit(false, false, false, true);
        emit Unpaused(manager);
        config.unpause();
        assertFalse(config.paused());
    }
}
