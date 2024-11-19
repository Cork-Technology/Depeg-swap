pragma solidity ^0.8.0;

import "./../../../Helper.sol";
import "./../../../../../contracts/dummy/DummyWETH.sol";

contract DepositTest is Helper {
    uint256 amount = 1 ether;

    function setUp() external {
        deployModuleCore();
        (DummyWETH ra,,) = initializeAndIssueNewDs(block.timestamp + 1 days);

        vm.startPrank(DEFAULT_ADDRESS);

        vm.deal(DEFAULT_ADDRESS, 10000000000 ether);

        ra.deposit{value: 10000000000 ether}();
        ra.approve(address(moduleCore), 10000000000 ether);
    }

    // TODO : adjust
    function test_depositLv() external {
        Id id = defaultCurrencyId;
        // (uint256 expectedLv, uint256 raTolerance, uint256 ctTolerance) = moduleCore.previewLvDeposit(id, amount);
        uint256 received = moduleCore.depositLv(id, amount, 0, 0);
        received = moduleCore.depositLv(id, amount, 0, 0);

        // vm.assertEq(received, expectedLv);
    }

    function test_RevertWhenToleranceIsWorking() external {
        Id id = defaultCurrencyId;

        // set the first deposit
        uint256 received = moduleCore.depositLv(id, amount, 0 ether, 0 ether);

        vm.expectRevert();
        received = moduleCore.depositLv(id, amount, 100000 ether, 10000 ether);
    }
}
