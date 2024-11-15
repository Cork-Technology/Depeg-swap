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


    function test_updateRateAfterUpdateCeilingShouldWork() external {
        uint256 newCeiling = 1.5 ether;

        corkConfig.updatePsmRateCeiling(defaultCurrencyId, newCeiling);
        
        uint256 rate = moduleCore.rateCeiling(defaultCurrencyId);
        vm.assertEq(rate, newCeiling);

        uint256 newRate = 1.2 ether;
        corkConfig.updatePsmRate(defaultCurrencyId, newRate);

        rate = moduleCore.exchangeRate(defaultCurrencyId);
        vm.assertEq(rate, newRate);
        
    }

    function test_revertWhenRateIsLowerThanCurrent() external {
        uint256 newCeiling = 1.5 ether;

        corkConfig.updatePsmRateCeiling(defaultCurrencyId, newCeiling);
        
        uint256 rate = moduleCore.rateCeiling(defaultCurrencyId);
        vm.assertEq(rate, newCeiling);

        uint256 newRate = 1.2 ether;
        corkConfig.updatePsmRate(defaultCurrencyId, newRate);

        rate = moduleCore.exchangeRate(defaultCurrencyId);
        vm.assertEq(rate, newRate);

        vm.expectRevert();
        corkConfig.updatePsmRate(defaultCurrencyId, 1 ether);
    }

    function test_RevertWhenRateIsHigherThanCeiling() external {
        uint256 newCeiling = 1.5 ether;

        corkConfig.updatePsmRateCeiling(defaultCurrencyId, newCeiling);
        
        uint256 rate = moduleCore.rateCeiling(defaultCurrencyId);
        vm.assertEq(rate, newCeiling);

        uint256 newRate = 1.2 ether;
        corkConfig.updatePsmRate(defaultCurrencyId, newRate);

        rate = moduleCore.exchangeRate(defaultCurrencyId);
        vm.assertEq(rate, newRate);

        vm.expectRevert();
        corkConfig.updatePsmRate(defaultCurrencyId, 1.6 ether);
    }
}
