pragma solidity ^0.8.0;

import "./../../../Helper.sol";
import "./../../../../../contracts/dummy/DummyWETH.sol";
import "./../../../../../contracts/core/assets/Asset.sol";
import "./../../../../../contracts/interfaces/IVault.sol";

contract DepositTest is Helper {
    uint256 amount = 1 ether;
    uint256 internal constant DEPOSIT_AMOUNT = 1_000_000_000 ether;

    function setUp() external {
        deployModuleCore();
        (DummyWETH ra,,) = initializeAndIssueNewDs(block.timestamp + 1 days);

        vm.startPrank(DEFAULT_ADDRESS);

        vm.deal(DEFAULT_ADDRESS, 1_000_000_000 ether);

        ra.deposit{value: 1_000_000_000 ether}();
        ra.approve(address(moduleCore), 1_000_000_000 ether);
    }

    function testFuzz_basicSanityDepositRedeem(uint256 amount) external {
        amount = bound(amount, 0.001 ether, DEPOSIT_AMOUNT);

        Id id = defaultCurrencyId;
        Asset lv = Asset(moduleCore.lvAsset(id));
        console.log("lv symbol: ", lv.symbol());

        uint256 balanceBefore = lv.balanceOf(DEFAULT_ADDRESS);

        uint256 received = moduleCore.depositLv(id, amount, 0, 0);
        received = moduleCore.depositLv(id, amount, 0, 0);

        uint256 balanceAfter = lv.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(balanceAfter, balanceBefore + received);

        lv.approve(address(moduleCore), received);

        IVault.RedeemEarlyParams memory redeemParams =
            IVault.RedeemEarlyParams({id: id, amount: received, amountOutMin: 0, ammDeadline: block.timestamp});

        moduleCore.redeemEarlyLv(redeemParams);
    }

    function test_RevertWhenToleranceIsWorking() external {
        Id id = defaultCurrencyId;

        // set the first deposit
        uint256 received = moduleCore.depositLv(id, amount, 0 ether, 0 ether);

        vm.expectRevert();
        received = moduleCore.depositLv(id, amount, 100000 ether, 10000 ether);
    }
}
