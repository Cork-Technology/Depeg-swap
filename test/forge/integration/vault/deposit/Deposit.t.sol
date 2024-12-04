pragma solidity ^0.8.0;

import "./../../../Helper.sol";
import "./../../../../../contracts/dummy/DummyWETH.sol";
import "./../../../../../contracts/core/assets/Asset.sol";
import "./../../../../../contracts/interfaces/IVault.sol";
import "./../../../../../contracts/interfaces/ICommon.sol";
import "./../../../../../contracts/libraries/State.sol";

contract DepositTest is Helper {
    uint256 amount = 1 ether;
    uint256 internal constant DEPOSIT_AMOUNT = 1_000_000 ether;

    mapping(address => uint256) public balances;

    uint256 dsId;
    address ct;
    address ds;

    DummyWETH ra;
    DummyWETH pa;

    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();
        (ra, pa,) = initializeAndIssueNewDs(block.timestamp + 1 days);

        vm.deal(DEFAULT_ADDRESS, 1_000_000_000 ether);
        ra.deposit{value: 1_000_000_000 ether}();
        ra.approve(address(moduleCore), 1_000_000_000 ether);

        vm.deal(DEFAULT_ADDRESS, 1_000_000 ether);
        pa.deposit{value: 1_000_000 ether}();
        pa.approve(address(moduleCore), 1_000_000 ether);

        fetchProtocolGeneralInfo();
    }

    function fetchProtocolGeneralInfo() internal {
        dsId = moduleCore.lastDsId(defaultCurrencyId);
        (ct, ds) = moduleCore.swapAsset(defaultCurrencyId, dsId);
    }

    // ff to expiry and update infos
    function ff_expired() internal {
        // fast forward to expiry
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry);

        issueNewDs(defaultCurrencyId);

        fetchProtocolGeneralInfo();
    }

    function test_basicSanityDepositRedeem() external {
        uint256 amount = 10 ether;
        uint256 psmDepositAmount = 1 ether;

        Id id = defaultCurrencyId;
        Asset lv = Asset(moduleCore.lvAsset(id));

        // fast forward to expiry, since we want to test it with amm

        ff_expired();

        // amount = bound(amount, 0.001 ether, DEPOSIT_AMOUNT);
        // psmDepositAmount = bound(psmDepositAmount, 0.0001 ether, DEPOSIT_AMOUNT / 2);

        uint256 received;

        {
            uint256 balanceBefore = lv.balanceOf(DEFAULT_ADDRESS);

            received = moduleCore.depositLv(id, amount, 0, 0);

            uint256 balanceAfter = lv.balanceOf(DEFAULT_ADDRESS);

            moduleCore.depositPsm(id, psmDepositAmount);

            // approve DS
            IERC20(ds).approve(address(moduleCore), psmDepositAmount);

            // redeem RA back so that we have PA in PSM
            moduleCore.redeemRaWithDs(id, dsId, psmDepositAmount);

            vm.assertEq(balanceAfter, balanceBefore + received);

            lv.approve(address(moduleCore), received);
        }

        // fast forward to expiry
        ff_expired();

        {
            VaultWithdrawalPool memory pool = moduleCore.getVaultWithdrawalPool(id);
            vm.assertTrue(pool.paBalance > 0);
        }

        IVault.RedeemEarlyParams memory redeemParams =
            IVault.RedeemEarlyParams({id: id, amount: received, amountOutMin: 0, ammDeadline: block.timestamp});

        // should fail since we have PA deposited in PSM
        vm.expectRevert(ICommon.LVDepositPaused.selector);
        received = moduleCore.depositLv(id, 1 ether, 0, 0);

        forceUnpause();
        IVault.RedeemEarlyResult memory result = moduleCore.redeemEarlyLv(redeemParams);

        vm.warp(block.timestamp + 3 days + 1);

        uint256 expectedTotalRaReceived = result.raIdleReceived + result.raReceivedFromAmm;
        uint256 expectedTotalCtReceived = result.ctReceivedFromAmm + result.ctReceivedFromVault;
        uint256 expectedDsReceived = result.dsReceived;
        uint256 expectedPaReceived = result.paReceived;

        uint256 raBefore = ra.balanceOf(DEFAULT_ADDRESS);
        uint256 dsBefore = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 ctBefore = IERC20(ct).balanceOf(DEFAULT_ADDRESS);
        uint256 paBefore = pa.balanceOf(DEFAULT_ADDRESS);

        withdrawalContract.claimToSelf(result.withdrawalId);

        uint256 raAfter = ra.balanceOf(DEFAULT_ADDRESS);
        uint256 dsAfter = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 ctAfter = IERC20(ct).balanceOf(DEFAULT_ADDRESS);
        uint256 paAfter = pa.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(raAfter, raBefore + expectedTotalRaReceived);
        vm.assertEq(dsAfter, dsBefore + expectedDsReceived);
        vm.assertEq(ctAfter, ctBefore + expectedTotalCtReceived);
        vm.assertEq(paAfter, paBefore + expectedPaReceived);
    }

    function test_depositRedeem() external {
        amount = bound(amount, 0.001 ether, DEPOSIT_AMOUNT);

        Id id = defaultCurrencyId;
        Asset lv = Asset(moduleCore.lvAsset(id));

        uint256 balanceBefore = lv.balanceOf(DEFAULT_ADDRESS);

        uint256 received = moduleCore.depositLv(id, amount, 0, 0);

        uint256 balanceAfter = lv.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(balanceAfter, balanceBefore + received);

        lv.approve(address(moduleCore), received);

        IVault.RedeemEarlyParams memory redeemParams =
            IVault.RedeemEarlyParams({id: id, amount: received, amountOutMin: 0, ammDeadline: block.timestamp});

        IVault.RedeemEarlyResult memory result = moduleCore.redeemEarlyLv(redeemParams);
        vm.warp(3 days + 1);

        Withdrawal.WithdrawalInfo memory info = withdrawalContract.getWithdrawal(result.withdrawalId);

        for (uint256 i = 0; i < info.tokens.length; i++) {
            // record balances before
            balances[info.tokens[i].token] = IERC20(info.tokens[i].token).balanceOf(DEFAULT_ADDRESS);
        }

        withdrawalContract.claimToSelf(result.withdrawalId);

        for (uint256 i = 0; i < info.tokens.length; i++) {
            // record balances after
            uint256 balanceAfterClaim = IERC20(info.tokens[i].token).balanceOf(DEFAULT_ADDRESS);
            vm.assertEq(balanceAfterClaim, balances[info.tokens[i].token] + info.tokens[i].amount);
        }
    }

    function test_RevertWhenToleranceIsWorking() external {
        Id id = defaultCurrencyId;

        // set the first deposit
        uint256 received = moduleCore.depositLv(id, amount, 0 ether, 0 ether);

        vm.expectRevert();
        received = moduleCore.depositLv(id, amount, 100000 ether, 10000 ether);
    }
}
