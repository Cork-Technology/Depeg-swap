pragma solidity ^0.8.0;

import "./../../../../contracts/dummy/DummyWETH.sol";
import "./../../Helper.sol";

contract rateTest is Helper {
    uint256 amount = 1 ether;

    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();
        (DummyWETH ra,,) = initializeAndIssueNewDs(block.timestamp + 1 days);

        vm.startPrank(DEFAULT_ADDRESS);

        vm.deal(DEFAULT_ADDRESS, 1000 ether);

        ra.deposit{value: 1000 ether}();
        ra.approve(address(moduleCore), 1000 ether);
    }

    function test_updateRateAfterUpdateCeilingShouldWorkInDelta() external {
        // new rate cannot be lower than 10% of current rate
        uint256 newRate = 0.9 ether;

        corkConfig.updatePsmRate(defaultCurrencyId, newRate);

        uint256 actualRate = moduleCore.exchangeRate(defaultCurrencyId);
        vm.assertEq(newRate, actualRate);
    }

    function test_revertWhenRateIsHigherThanCurrent() external {
        uint256 newRate = 1.1 ether;

        vm.expectRevert();
        corkConfig.updatePsmRate(defaultCurrencyId, newRate);
    }

    function test_revertWhenNewRateIsLessThanDelta() external {
        uint256 newRate = 0.8 ether;

        vm.expectRevert();
        corkConfig.updatePsmRate(defaultCurrencyId, newRate);
    }

    function test_revertWhenUpdaterTryToChangeOtherConfig() external {
        // grant only updater role to random address
        address maliciousUser = address(420);

        corkConfig.grantRole(corkConfig.RATE_UPDATERS_ROLE(), maliciousUser);
        vm.stopPrank();

        vm.startPrank(maliciousUser);

        // irrelevant
        uint256 newRate = 1 ether;

        vm.expectRevert();
        corkConfig.updateEarlyRedemptionFeeRate(defaultCurrencyId, newRate);
    }
}
