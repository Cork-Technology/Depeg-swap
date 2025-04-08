// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CTOracle} from "../../../../contracts/core/oracles/CTOracle.sol";
import {CTOracleFactory} from "../../../../contracts/core/oracles/CTOracleFactory.sol";
import {ICTOracleFactory} from "../../../../contracts/interfaces/ICTOracleFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CTOracleTest is Test {
    CTOracle public oracle;
    CTOracleFactory public factory;

    address public factoryOwner;
    address public user;
    address public ctToken;

    function setUp() public {
        factoryOwner = makeAddr("factoryOwner");
        user = makeAddr("user");
        ctToken = makeAddr("ctToken");

        vm.startPrank(factoryOwner);
        // Deploy factory implementation
        CTOracleFactory implementation = new CTOracleFactory();

        // Deploy proxy with implementation
        bytes memory initData = abi.encodeWithSelector(implementation.initialize.selector, factoryOwner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        factory = CTOracleFactory(address(proxy));
        vm.stopPrank();

        vm.startPrank(user);
        // Create an oracle using the factory
        address oracleAddress = factory.createCTOracle(ctToken);
        oracle = CTOracle(oracleAddress);
        vm.stopPrank();
    }

    function test_OracleInitialization() public {
        // Oracle should be owned by the factory
        assertEq(oracle.owner(), address(factory));
    }

    function test_OracleInitializationRevertsWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new CTOracle(address(0));
    }

    function test_OracleOwnershipControl() public {
        // User cannot control oracle directly
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        oracle.transferOwnership(user);
        vm.stopPrank();

        // Factory owner also cannot directly control oracle
        vm.startPrank(factoryOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, factoryOwner));
        oracle.transferOwnership(factoryOwner);
        vm.stopPrank();
    }

    function test_OracleOwnershipTransfer() public {
        assertEq(oracle.owner(), address(factory));

        // Only the factory can transfer oracle ownership
        vm.prank(address(factory));
        oracle.transferOwnership(user);

        // Verify the ownership was transferred
        assertEq(oracle.owner(), user);

        // New owner can now execute owner-only functions
        vm.prank(user);
        oracle.transferOwnership(factoryOwner);

        // Verify the ownership was transferred again
        assertEq(oracle.owner(), factoryOwner);
    }
}
