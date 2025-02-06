pragma solidity ^0.8.0;

import "./../../../Helper.sol";
import "./../../../../../contracts/dummy/DummyWETH.sol";
import "./../../../../../contracts/core/assets/Asset.sol";
import "./../../../../../contracts/interfaces/IVault.sol";
import "./../../../../../contracts/interfaces/IErrors.sol";
import "./../../../../../contracts/libraries/State.sol";
import "./../../../../../contracts/libraries/TransferHelper.sol";

contract DepositTest is Helper {
    uint256 amount = 1 ether;
    uint256 internal constant DEPOSIT_AMOUNT = 1_000_000 ether;
    uint256 public constant EXPIRY = 1 days;

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

    function setupDifferentDecimals(uint8 raDecimals, uint8 paDecimals) internal returns (uint8, uint8) {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        uint8 lowDecimals = 6;
        uint8 highDecimals = 32;

        // bound decimals to minimum of 18 and max of 64
        raDecimals = uint8(bound(raDecimals, lowDecimals, highDecimals));
        paDecimals = uint8(bound(paDecimals, lowDecimals, highDecimals));

        (ra, pa, defaultCurrencyId) = initializeAndIssueNewDs(EXPIRY, raDecimals, paDecimals);

        vm.deal(DEFAULT_ADDRESS, type(uint256).max);
        ra.deposit{value: type(uint256).max}();
        ra.approve(address(moduleCore), type(uint256).max);

        vm.deal(DEFAULT_ADDRESS, type(uint256).max);
        pa.deposit{value: type(uint256).max}();
        pa.approve(address(moduleCore), type(uint256).max);

        fetchProtocolGeneralInfo();

        return (raDecimals, paDecimals);
    }

    function testFuzz_deposit(uint8 raDecimals, uint8 paDecimals) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        uint256 depositAmount = 1 ether;

        uint256 adjustedDepositAmount = TransferHelper.normalizeDecimals(depositAmount, TARGET_DECIMALS, raDecimals);

        uint256 received = moduleCore.depositLv(defaultCurrencyId, adjustedDepositAmount, 0, 0);

        VaultBalances memory balances = moduleCore.getVaultBalances(defaultCurrencyId);
        vm.assertEq(balances.ra.locked, 0);

        // default split is 50/50
        vm.assertEq(balances.ctBalance, 0.5 ether);

        uint256 dsReserve = flashSwapRouter.getLvReserve(defaultCurrencyId, 1);
        // ~0.5 from split, ~0.2 from AMM with some precision tolerance
        vm.assertApproxEqAbs(dsReserve, 0.76 ether, 0.01 ether);

        ff_expired();

        balances = moduleCore.getVaultBalances(defaultCurrencyId);
        vm.assertEq(balances.ra.locked, 0);

        dsReserve = flashSwapRouter.getLvReserve(defaultCurrencyId, 1);
        // the Ds reserve should stay the same but the ct splitted should be 0
        vm.assertApproxEqAbs(dsReserve, 0.76 ether, 0.01 ether);

        vm.assertEq(balances.ctBalance, 0);
    }

    function testFuzz_redeem(uint8 raDecimals, uint8 paDecimals) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        uint256 depositAmount = 1 ether;

        uint256 adjustedDepositAmount = TransferHelper.normalizeDecimals(depositAmount, TARGET_DECIMALS, raDecimals);

        uint256 received = moduleCore.depositLv(defaultCurrencyId, adjustedDepositAmount, 0, 0);

        VaultBalances memory balances = moduleCore.getVaultBalances(defaultCurrencyId);
        vm.assertEq(balances.ra.locked, 0);

        // default split is 50/50
        vm.assertEq(balances.ctBalance, 0.5 ether);

        uint256 dsReserve = flashSwapRouter.getLvReserve(defaultCurrencyId, 1);
        // ~0.5 from split, ~0.2 from AMM with some precision tolerance
        vm.assertApproxEqAbs(dsReserve, 0.76 ether, 0.01 ether);

        ff_expired();

        balances = moduleCore.getVaultBalances(defaultCurrencyId);
        vm.assertEq(balances.ra.locked, 0);

        dsReserve = flashSwapRouter.getLvReserve(defaultCurrencyId, 2);
        vm.assertApproxEqAbs(dsReserve, 0.5 ether, 0.01 ether);

        vm.assertEq(balances.ctBalance, 0);

        IVault.RedeemEarlyParams memory redeemParams;
        {
            Id id = defaultCurrencyId;
            Asset lv = Asset(moduleCore.lvAsset(id));
            uint256 balance = lv.balanceOf(DEFAULT_ADDRESS);
            lv.approve(address(moduleCore), balance);
            redeemParams = IVault.RedeemEarlyParams(id, balance, 0, block.timestamp, 0, 0, 0);
        }

        IVault.RedeemEarlyResult memory result = moduleCore.redeemEarlyLv(redeemParams);
        vm.assertApproxEqAbs(result.ctReceivedFromAmm, 0.5 ether, 0.01 ether);
        vm.assertApproxEqAbs(result.dsReceived, 0.5 ether, 0.01 ether);

        uint256 expectedRaReceived = TransferHelper.normalizeDecimals(0.49 ether, TARGET_DECIMALS, raDecimals);
        uint256 errorDelta = TransferHelper.normalizeDecimals(0.01 ether, TARGET_DECIMALS, raDecimals);

        vm.assertApproxEqAbs(result.raReceivedFromAmm, expectedRaReceived, errorDelta);
        vm.assertApproxEqAbs(result.raIdleReceived, 0, 0);
        vm.assertApproxEqAbs(result.paReceived, 0, 0);

        {
            vm.warp(10 days);
            uint256 raBefore = ra.balanceOf(DEFAULT_ADDRESS);
            uint256 dsBefore = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
            uint256 ctBefore = IERC20(ct).balanceOf(DEFAULT_ADDRESS);
            uint256 paBefore = pa.balanceOf(DEFAULT_ADDRESS);

            withdrawalContract.claimToSelf(result.withdrawalId);

            uint256 raAfter = ra.balanceOf(DEFAULT_ADDRESS);
            uint256 dsAfter = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
            uint256 ctAfter = IERC20(ct).balanceOf(DEFAULT_ADDRESS);
            uint256 paAfter = pa.balanceOf(DEFAULT_ADDRESS);

            vm.assertApproxEqAbs(raAfter, raBefore + expectedRaReceived, errorDelta);
            vm.assertApproxEqAbs(dsAfter, dsBefore + 0.5 ether, 0.01 ether);
            vm.assertApproxEqAbs(ctAfter, ctBefore + 0.5 ether, 0.01 ether);
            vm.assertApproxEqAbs(paAfter, paBefore, 0);
        }
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

        uint256 received;

        {
            uint256 balanceBefore = lv.balanceOf(DEFAULT_ADDRESS);

            received = moduleCore.depositLv(id, amount, 0, 0);

            uint256 balanceAfter = lv.balanceOf(DEFAULT_ADDRESS);

            moduleCore.depositPsm(id, psmDepositAmount);

            // approve DS
            IERC20(ds).approve(address(moduleCore), psmDepositAmount);

            // redeem RA back so that we have PA in PSM
            moduleCore.redeemRaWithDsPa(id, dsId, psmDepositAmount);

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
            IVault.RedeemEarlyParams(id, received, 0, block.timestamp, 0, 0, 0);

        // should fail since we have PA deposited in PSM
        vm.expectRevert(IErrors.LVDepositPaused.selector);
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
            IVault.RedeemEarlyParams(id, received, 0, block.timestamp, 0, 0, 0);

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

    function test_redeemStateFailure() external {
        uint256 amount = 10 ether;
        uint256 psmDepositAmount = 1 ether;

        Id id = defaultCurrencyId;
        // disable ct split so that we can get accurate info
        corkConfig.updateLvStrategyCtSplitPercentage(id, 0);

        Asset lv = Asset(moduleCore.lvAsset(id));

        // fast forward to expiry, since we want to test it with amm
        ff_expired();

        uint256 received;

        {
            uint256 balanceBefore = lv.balanceOf(DEFAULT_ADDRESS);

            received = moduleCore.depositLv(id, amount, 0, 0);

            uint256 balanceAfter = lv.balanceOf(DEFAULT_ADDRESS);

            moduleCore.depositPsm(id, psmDepositAmount);

            // approve DS
            IERC20(ds).approve(address(moduleCore), psmDepositAmount);

            // redeem RA back so that we have PA in PSM
            moduleCore.redeemRaWithDsPa(id, dsId, psmDepositAmount);

            vm.assertEq(balanceAfter, balanceBefore + received);

            lv.approve(address(moduleCore), received);
        }

        // fast forward to expiry
        ff_expired();

        {
            VaultWithdrawalPool memory pool = moduleCore.getVaultWithdrawalPool(id);
            vm.assertTrue(pool.paBalance > 0);
        }

        IVault.RedeemEarlyParams memory redeemParams = IVault.RedeemEarlyParams({
            id: id,
            amount: received / 3,
            amountOutMin: 0,
            ammDeadline: block.timestamp,
            ctAmountOutMin: 0,
            dsAmountOutMin: 0,
            paAmountOutMin: 0
        });

        // should fail since we have PA deposited in PSM
        vm.expectRevert(IErrors.LVDepositPaused.selector);
        received = moduleCore.depositLv(id, 1 ether, 0, 0);

        forceUnpause();
        IVault.RedeemEarlyResult memory result1 = moduleCore.redeemEarlyLv(redeemParams);
        IVault.RedeemEarlyResult memory result2 = moduleCore.redeemEarlyLv(redeemParams);
        IVault.RedeemEarlyResult memory result3 = moduleCore.redeemEarlyLv(redeemParams); //This will cause a reversion
    }

    function test_redeemStateFailureStrict() external {
        uint256 amount = 10 ether;
        uint256 psmDepositAmount = 1 ether;

        Id id = defaultCurrencyId;
        Asset lv = Asset(moduleCore.lvAsset(id));

        // fast forward to expiry, since we want to test it with amm
        ff_expired();

        uint256 received;

        {
            uint256 balanceBefore = lv.balanceOf(DEFAULT_ADDRESS);

            received = moduleCore.depositLv(id, amount, 0, 0);

            uint256 balanceAfter = lv.balanceOf(DEFAULT_ADDRESS);

            moduleCore.depositPsm(id, psmDepositAmount);

            // approve DS
            IERC20(ds).approve(address(moduleCore), psmDepositAmount);

            // redeem RA back so that we have PA in PSM
            moduleCore.redeemRaWithDsPa(id, dsId, psmDepositAmount);

            vm.assertEq(balanceAfter, balanceBefore + amount); //we expect the first deposit to get exactly the same amount that it put in

            lv.approve(address(moduleCore), 2 ** 256 - 1);
        }

        moduleCore.depositLv(id, amount, 0, 0); // a second deposit
        assertApproxEqAbs(received = lv.balanceOf(DEFAULT_ADDRESS), amount * 2, amount / 500); // there is going to be less than a 0.1% difference
        // fast forward to expiry
        ff_expired();

        {
            VaultWithdrawalPool memory pool = moduleCore.getVaultWithdrawalPool(id);
            vm.assertTrue(pool.paBalance > 0);
        }

        IVault.RedeemEarlyParams memory redeemParams = IVault.RedeemEarlyParams({
            id: id,
            amount: received / 8,
            amountOutMin: 0,
            ammDeadline: block.timestamp,
            ctAmountOutMin: 0,
            dsAmountOutMin: 0,
            paAmountOutMin: 0
        });

        // should fail since we have PA deposited in PSM
        vm.expectRevert(IErrors.LVDepositPaused.selector);
        moduleCore.depositLv(id, 1 ether, 0, 0);

        forceUnpause();

        uint256 totalPaBalance = moduleCore.liquidationFundsAvailable(id);
        uint256 totalRaBalance = moduleCore.tradeExecutionFundsAvailable(id);
        uint256 totalLpBalance = moduleCore.vaultLp(id);
        uint256 totalDsBalance = flashSwapRouter.getLvReserve(id, dsId);

        assertEq(lv.balanceOf(DEFAULT_ADDRESS), received);
        for (uint256 i = 0; i < 8; i++) {
            moduleCore.redeemEarlyLv(redeemParams);
            assertApproxEqAbs(lv.balanceOf(DEFAULT_ADDRESS), received * (7 - i) / 8, 100);
            assertApproxEqAbs(moduleCore.liquidationFundsAvailable(id), totalPaBalance * (7 - i) / 8, 100);
            assertApproxEqAbs(moduleCore.tradeExecutionFundsAvailable(id), totalRaBalance * (7 - i) / 8, 100);
            assertApproxEqAbs(lv.totalSupply(), received * (7 - i) / 8, 100);
            assertApproxEqAbs(moduleCore.vaultLp(id), totalLpBalance * (7 - i) / 8, 100);
            assertApproxEqAbs(flashSwapRouter.getLvReserve(id, dsId), totalDsBalance * (7 - i) / 8, 100);
            // we may also want to check the tokens are in this address, but that'll blow up the stack
        }

        // Sanity check it is all basically empty
        assertLe(moduleCore.liquidationFundsAvailable(id), 10);
        assertLe(moduleCore.tradeExecutionFundsAvailable(id), 10);
        assertLe(lv.totalSupply(), 10);
        assertLe(moduleCore.vaultLp(id), 10);
        assertLe(flashSwapRouter.getLvReserve(id, dsId), 10);
    }

    function testFuzz_redeemStateFailureStrict(uint8 raDecimals, uint8 paDecimals) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        uint256 rawAmount = 10 ether;
        uint256 amount = TransferHelper.normalizeDecimals(rawAmount, TARGET_DECIMALS, raDecimals);

        Id id = defaultCurrencyId;
        Asset lv = Asset(moduleCore.lvAsset(id));

        // fast forward to expiry, since we want to test it with amm
        ff_expired();

        uint256 received;

        {
            uint256 psmDepositAmount = TransferHelper.normalizeDecimals(1 ether, TARGET_DECIMALS, raDecimals);

            uint256 balanceBefore = lv.balanceOf(DEFAULT_ADDRESS);

            received = moduleCore.depositLv(id, amount, 0, 0);

            uint256 balanceAfter = lv.balanceOf(DEFAULT_ADDRESS);

            moduleCore.depositPsm(id, psmDepositAmount);

            // normalize pa redeemAmount
            uint256 paRedeemAmount = TransferHelper.normalizeDecimals(psmDepositAmount, raDecimals, paDecimals);

            // approve DS
            IERC20(ds).approve(address(moduleCore), 1 ether);

            // redeem RA back so that we have PA in PSM
            moduleCore.redeemRaWithDsPa(id, dsId, paRedeemAmount);

            vm.assertEq(balanceAfter, balanceBefore + rawAmount); //we expect the first deposit to get exactly the same amount that it put in, and to be in the same decimals as the LV

            lv.approve(address(moduleCore), 2 ** 256 - 1);
        }

        {
            moduleCore.depositLv(id, amount, 0, 0); // a second deposit
            uint256 expectedLvBalance = TransferHelper.normalizeDecimals(amount * 2, raDecimals, TARGET_DECIMALS);
            assertApproxEqAbs(received = lv.balanceOf(DEFAULT_ADDRESS), expectedLvBalance, expectedLvBalance / 500); // there is going to be less than a 0.1% difference
        }
        // fast forward to expiry
        ff_expired();

        {
            VaultWithdrawalPool memory pool = moduleCore.getVaultWithdrawalPool(id);
            vm.assertTrue(pool.paBalance > 0);
        }

        IVault.RedeemEarlyParams memory redeemParams = IVault.RedeemEarlyParams({
            id: id,
            amount: received / 8,
            amountOutMin: 0,
            ammDeadline: block.timestamp,
            ctAmountOutMin: 0,
            dsAmountOutMin: 0,
            paAmountOutMin: 0
        });

        // should fail since we have PA deposited in PSM
        {
            vm.expectRevert(IErrors.LVDepositPaused.selector);
            moduleCore.depositLv(id, 1 ether, 0, 0);
        }

        forceUnpause();

        uint256 totalPaBalance = moduleCore.liquidationFundsAvailable(id);
        uint256 totalRaBalance = moduleCore.tradeExecutionFundsAvailable(id);
        uint256 totalLpBalance = moduleCore.vaultLp(id);
        uint256 totalDsBalance = flashSwapRouter.getLvReserve(id, dsId);

        uint256 deltaRa = TransferHelper.normalizeDecimals(100, TARGET_DECIMALS, raDecimals);
        uint256 deltaPa = TransferHelper.normalizeDecimals(100, TARGET_DECIMALS, paDecimals);

        // just we can have some margin for rounding errors
        // it's quite big since we're potentially dealing with high decimal numbers
        // say 29 for example, so we set it to 10 to have some wiggle room
        deltaRa = deltaRa <= 1 ? 10 : deltaRa;
        deltaPa = deltaPa <= 1 ? 10 : deltaPa;

        assertEq(lv.balanceOf(DEFAULT_ADDRESS), received);

        for (uint256 i = 0; i < 8; i++) {
            moduleCore.redeemEarlyLv(redeemParams);

            assertApproxEqAbs(lv.balanceOf(DEFAULT_ADDRESS), received * (7 - i) / 8, 100);
            assertApproxEqAbs(moduleCore.liquidationFundsAvailable(id), totalPaBalance * (7 - i) / 8, deltaPa);
            assertApproxEqAbs(moduleCore.tradeExecutionFundsAvailable(id), totalRaBalance * (7 - i) / 8, deltaRa);
            assertApproxEqAbs(lv.totalSupply(), received * (7 - i) / 8, 100);
            assertApproxEqAbs(moduleCore.vaultLp(id), totalLpBalance * (7 - i) / 8, 100);
            assertApproxEqAbs(flashSwapRouter.getLvReserve(id, dsId), totalDsBalance * (7 - i) / 8, 100);
            // we may also want to check the tokens are in this address, but that'll blow up the stack
        }

        // Sanity check it is all basically empty
        assertLe(moduleCore.liquidationFundsAvailable(id), deltaPa);
        assertLe(moduleCore.tradeExecutionFundsAvailable(id), deltaRa);
        assertLe(lv.totalSupply(), 10);
        assertLe(moduleCore.vaultLp(id), 10);
        assertLe(flashSwapRouter.getLvReserve(id, dsId), 10);
    }
}
