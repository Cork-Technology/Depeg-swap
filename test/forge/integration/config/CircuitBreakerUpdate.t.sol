pragma solidity ^0.8.24;

import "./../../Helper.sol";
import "./../../../../contracts/libraries/State.sol";
import "./../../../../contracts/dummy/DummyWETH.sol";

contract CircuiBreakerUpdate is Helper {
    DummyWETH ra;
    DummyWETH pa;

    function setUp() external {
        vm.warp(10 days);

        vm.startPrank(DEFAULT_ADDRESS);
        deployModuleCore();
        (ra, pa,) = initializeAndIssueNewDs(block.timestamp + 10 days);

        vm.deal(DEFAULT_ADDRESS, 1_000_000_000 ether);
        ra.deposit{value: 1_000_000_000 ether}();
        ra.approve(address(moduleCore), 1_000_000_000 ether);

        vm.deal(DEFAULT_ADDRESS, 1_000_000 ether);
        pa.deposit{value: 1_000_000 ether}();
        pa.approve(address(moduleCore), 1_000_000 ether);
    }

    function test_shouldUpdateCircuitBreaker() external {
        // dummy deposit to get nav
        moduleCore.depositLv(defaultCurrencyId, 100 ether, 0, 0, 0, block.timestamp);

        VaultConfig memory config = moduleCore.getVaultConfig(defaultCurrencyId);

        vm.assertNotEq(config.navCircuitBreaker.lastUpdate0, 0);
        vm.assertEq(config.navCircuitBreaker.lastUpdate1, 0);

        vm.assertNotEq(config.navCircuitBreaker.snapshot0, 0);
        vm.assertEq(config.navCircuitBreaker.snapshot1, 0);

        vm.warp(block.timestamp + 1 days);

        corkConfig.forceUpdateNavCircuitBreakerReferenceValue(defaultCurrencyId);

        config = moduleCore.getVaultConfig(defaultCurrencyId);

        vm.assertNotEq(config.navCircuitBreaker.lastUpdate0, 0);
        vm.assertNotEq(config.navCircuitBreaker.lastUpdate1, 0);

        vm.assertNotEq(config.navCircuitBreaker.snapshot0, 0);
        vm.assertNotEq(config.navCircuitBreaker.snapshot1, 0);
    }
}
