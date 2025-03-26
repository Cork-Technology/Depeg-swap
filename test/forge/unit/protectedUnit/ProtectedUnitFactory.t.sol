// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {IErrors} from "../../../../contracts/interfaces/IErrors.sol";
import {ProtectedUnitFactoryV2Mock} from "./mocks/ProtectedUnitFactoryV2Mock.sol";
import {ProtectedUnitFactory} from "../../../../contracts/core/assets/ProtectedUnitFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProtectedUnit} from "../../../../contracts/core/assets/ProtectedUnit.sol";

contract ProtectedUnitFactoryTest is Helper {
    address public owner;
    address public user;

    uint256 internal USER_PK = 1;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Setup accounts
        owner = address(this); // Owner of the contract
        user = vm.rememberKey(USER_PK);

        deployModuleCore();
        vm.stopPrank();
    }

    function test_InitializationSetsCorrectValues() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Deploy a fresh instance to test initialization directly
        ProtectedUnitFactory implementation = new ProtectedUnitFactory();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                implementation.initialize.selector,
                address(moduleCore),
                address(corkConfig),
                address(flashSwapRouter),
                address(permit2),
                protectedUnitImpl
            )
        );
        ProtectedUnitFactory factory = ProtectedUnitFactory(address(proxy));

        // Check that all state variables are set correctly
        assertEq(factory.moduleCore(), address(moduleCore));
        assertEq(factory.config(), address(corkConfig));
        assertEq(factory.router(), address(flashSwapRouter));
        assertEq(factory.permit2(), address(permit2));
        assertEq(factory.owner(), address(DEFAULT_ADDRESS));
        vm.stopPrank();
    }

    function test_InitializationRevertsWithZeroAddress() public {
        // Deploy a fresh implementation
        ProtectedUnitFactory implementation = new ProtectedUnitFactory();

        // Try to initialize with zero address for moduleCore
        bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            address(0),
            address(corkConfig),
            address(flashSwapRouter),
            address(permit2),
            protectedUnitImpl
        );

        vm.expectRevert(IErrors.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), initData);

        // Try with zero address for config
        initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            address(moduleCore),
            address(0),
            address(flashSwapRouter),
            address(permit2),
            protectedUnitImpl
        );

        vm.expectRevert(IErrors.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), initData);

        // Try with zero address for router
        initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            address(moduleCore),
            address(corkConfig),
            address(0),
            address(permit2),
            protectedUnitImpl
        );

        vm.expectRevert(IErrors.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), initData);

        // Try with zero address for permit2
        initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            address(moduleCore),
            address(corkConfig),
            address(flashSwapRouter),
            address(0),
            protectedUnitImpl
        );

        vm.expectRevert(IErrors.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_InitializeCanOnlyBeCalledOnce() public {
        // Get the existing factory instance that was deployed in setUp()
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        protectedUnitFactory.initialize(
            address(moduleCore), address(corkConfig), address(flashSwapRouter), address(permit2), protectedUnitImpl
        );
    }

    function test_UpgradeSucceedsWhenCalledByOwner() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Deploy a new implementation
        ProtectedUnitFactoryV2Mock newImplementation = new ProtectedUnitFactoryV2Mock();

        // Store current state to verify it's preserved
        address oldModuleCore = protectedUnitFactory.moduleCore();
        address oldConfig = protectedUnitFactory.config();
        address oldRouter = protectedUnitFactory.router();
        address oldPermit2 = protectedUnitFactory.permit2();

        // Upgrade to the new implementation
        protectedUnitFactory.upgradeToAndCall(address(newImplementation), "");

        // Cast to V2Mock to access new functions
        ProtectedUnitFactoryV2Mock upgradedFactory = ProtectedUnitFactoryV2Mock(address(protectedUnitFactory));

        // Verify that state was preserved
        assertEq(upgradedFactory.moduleCore(), oldModuleCore);
        assertEq(upgradedFactory.config(), oldConfig);
        assertEq(upgradedFactory.router(), oldRouter);
        assertEq(upgradedFactory.permit2(), oldPermit2);

        // Test new function from V2
        assertEq(upgradedFactory.getVersion(), "V2");
        vm.stopPrank();
    }

    function test_UpgradeRevertsWhenCalledByNonOwner() public {
        // Deploy a new implementation
        ProtectedUnitFactoryV2Mock newImplementation = new ProtectedUnitFactoryV2Mock();

        // Try to upgrade from non-owner account
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        protectedUnitFactory.upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();
    }
}
