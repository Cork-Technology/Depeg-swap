// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CTOracleFactory} from "../../../../contracts/core/oracles/CTOracleFactory.sol";
import {CTOracle} from "../../../../contracts/core/oracles/CTOracle.sol";
import {ICTOracleFactory} from "../../../../contracts/interfaces/ICTOracleFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Mock implementation for testing upgradeability
contract CTOracleFactoryV2Mock is CTOracleFactory {
    function getVersion() external pure returns (string memory) {
        return "V2";
    }

    function newFunction() external pure returns (bool) {
        return true;
    }
}

contract CTOracleFactoryTest is Test {
    CTOracleFactory public factory;
    CTOracleFactory public implementation;
    CTOracleFactoryV2Mock public v2Implementation;

    address public owner;
    address public user;
    address public ctToken1;
    address public ctToken2;

    event CTOracleCreated(address indexed ctToken, address indexed oracle);

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        ctToken1 = makeAddr("ctToken1");
        ctToken2 = makeAddr("ctToken2");

        // Deploy implementation
        implementation = new CTOracleFactory();

        // Deploy proxy with implementation
        bytes memory initData = abi.encodeWithSelector(implementation.initialize.selector, owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        factory = CTOracleFactory(address(proxy));

        // Deploy V2 implementation for upgrade tests
        v2Implementation = new CTOracleFactoryV2Mock();
    }

    function test_Initialization() public {
        // Check owner is set correctly
        assertEq(factory.owner(), owner);
    }

    function test_InitializationRevertsWithZeroAddress() public {
        CTOracleFactory newImplementation = new CTOracleFactory();

        bytes memory initData = abi.encodeWithSelector(newImplementation.initialize.selector, address(0));

        vm.expectRevert(ICTOracleFactory.ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);
    }

    function test_CreateCTOracle() public {
        assertEq(factory.ctToOracle(ctToken1), address(0));

        // Expect CTOracleCreated event
        vm.expectEmit(true, false, false, false);
        emit CTOracleCreated(ctToken1, address(0));
        address oracle = factory.createCTOracle(ctToken1);

        // Check mapping is updated
        assertEq(factory.ctToOracle(ctToken1), oracle);
    }

    function test_CreateCTOracleRevertsForZeroAddress() public {
        vm.expectRevert(ICTOracleFactory.ZeroAddress.selector);
        factory.createCTOracle(address(0));
    }

    function test_CreateCTOracleRevertsForExistingOracle() public {
        // Create first oracle
        factory.createCTOracle(ctToken1);

        // Try to create another oracle for the same token
        vm.expectRevert(ICTOracleFactory.OracleAlreadyExists.selector);
        factory.createCTOracle(ctToken1);
    }

    function test_CreateMultipleOracles() public {
        // Create first oracle
        address oracle1 = factory.createCTOracle(ctToken1);

        // Create second oracle
        address oracle2 = factory.createCTOracle(ctToken2);

        // Check both mappings are updated
        assertEq(factory.ctToOracle(ctToken1), oracle1);
        assertEq(factory.ctToOracle(ctToken2), oracle2);

        // Verify different oracles were created
        assertNotEq(oracle1, oracle2);
    }

    function test_UpgradeToV2() public {
        // Verify we're using V1 (implementation doesn't have getVersion)
        (bool success,) = address(factory).call(abi.encodeWithSignature("getVersion()"));
        assertFalse(success, "Should not have getVersion() before upgrade");

        // Only owner can upgrade
        vm.startPrank(owner);
        factory.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();

        // Verify upgrade was successful by checking new function
        CTOracleFactoryV2Mock upgradedFactory = CTOracleFactoryV2Mock(address(factory));
        assertEq(upgradedFactory.getVersion(), "V2");
        assertTrue(upgradedFactory.newFunction());

        // Verify existing state was preserved
        address oracle = factory.createCTOracle(ctToken1);
        assertEq(factory.ctToOracle(ctToken1), oracle);
    }

    function test_UpgradeRevertsForNonOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();
    }

    function test_CanCreateOraclesAfterUpgrade() public {
        // Upgrade to V2
        factory.upgradeToAndCall(address(v2Implementation), "");

        // Verify we can still create oracles
        address oracle = factory.createCTOracle(ctToken1);
        assertEq(factory.ctToOracle(ctToken1), oracle);
    }

    function test_TransferOwnership() public {
        // Transfer ownership to user
        factory.transferOwnership(user);

        // Verify owner is updated
        assertEq(factory.owner(), user);

        // Original owner cannot upgrade anymore
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        factory.upgradeToAndCall(address(v2Implementation), "");

        // New owner can upgrade
        vm.startPrank(user);
        factory.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();
    }

    function testFuzz_CreateMultipleOracles(address[5] memory ctTokens) public {
        // Filter out zero address and duplicates
        for (uint256 i = 0; i < ctTokens.length; i++) {
            if (ctTokens[i] == address(0)) {
                ctTokens[i] = makeAddr(string(abi.encodePacked("token", i)));
            }

            // Check for duplicates with previous tokens
            for (uint256 j = 0; j < i; j++) {
                if (ctTokens[i] == ctTokens[j]) {
                    ctTokens[i] = makeAddr(string(abi.encodePacked("unique", i)));
                }
            }
        }

        // Create oracles for all tokens
        address[] memory oracles = new address[](ctTokens.length);
        for (uint256 i = 0; i < ctTokens.length; i++) {
            oracles[i] = factory.createCTOracle(ctTokens[i]);

            // Verify mapping is correct
            assertEq(factory.ctToOracle(ctTokens[i]), oracles[i]);
        }
    }
}
