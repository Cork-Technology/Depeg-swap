pragma solidity ^0.8.24;

import "../../../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "../../../Helper.sol";
import {DummyWETH} from "../../../../../contracts/dummy/DummyWETH.sol";
import "../../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "../../../../../contracts/libraries/Pair.sol";
import "../../../../../contracts/interfaces/IPSMcore.sol";
import "../../../../../contracts/interfaces/IDsFlashSwapRouter.sol";
import "forge-std/console.sol";

contract BuyDsTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    address ct;
    address ds;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;

    uint256 end = block.timestamp + 10 days;
    uint256 current = block.timestamp + 1 days;

    uint256 public dsId;

    uint256 stateId;

    function defaultInitialArp() internal pure virtual override returns (uint256) {
        return 5 ether;
    }

    function defaultExchangeRate() internal pure virtual override returns (uint256) {
        return 1.1 ether;
    }

    function snapshotRouterState() internal {
        stateId = vm.snapshotState();
    }

    function revertRouterState() internal {
        vm.revertToStateAndDelete(stateId);
        stateId = 0;
    }

    function setUp() public virtual {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(end);

        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);

        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        ra.approve(address(moduleCore), 100_000_000_000 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0);

        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);

        vm.stopPrank();
        vm.prank(address(corkConfig));
        flashSwapRouter.updateGradualSaleStatus(currencyId, true);
        vm.startPrank(DEFAULT_ADDRESS);
        fetchProtocolGeneralInfo();
    }

    function setupDifferentDecimals(uint8 raDecimals, uint8 paDecimals) internal returns (uint8, uint8) {
        uint8 lowDecimals = 6;
        uint8 highDecimals = 32;

        // bound decimals to minimum of 18 and max of 64
        raDecimals = uint8(bound(raDecimals, lowDecimals, highDecimals));
        paDecimals = uint8(bound(paDecimals, lowDecimals, highDecimals));

        (ra, pa, defaultCurrencyId) = initializeAndIssueNewDs(10 days, raDecimals, paDecimals);
        currencyId = defaultCurrencyId;

        vm.deal(DEFAULT_ADDRESS, type(uint256).max);
        ra.deposit{value: type(uint256).max}();
        ra.approve(address(moduleCore), type(uint256).max);

        vm.deal(DEFAULT_ADDRESS, type(uint256).max);
        pa.deposit{value: type(uint256).max}();
        pa.approve(address(moduleCore), type(uint256).max);

        fetchProtocolGeneralInfo();

        vm.stopPrank();
        vm.prank(address(corkConfig));
        flashSwapRouter.updateGradualSaleStatus(currencyId, false);
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 depositAmount = TransferHelper.normalizeDecimals(DEFAULT_DEPOSIT_AMOUNT, TARGET_DECIMALS, raDecimals);

        moduleCore.depositPsm(currencyId, depositAmount);
        moduleCore.depositLv(currencyId, depositAmount, 0, 0);

        return (raDecimals, paDecimals);
    }

    function test_buyDS() public virtual {
        ra.approve(address(flashSwapRouter), type(uint256).max);

        (uint256 raReserve, uint256 ctReserve) = hook.getReserves(address(ra), address(ct));

        uint256 amount = 0.5 ether;

        Asset(ds).approve(address(flashSwapRouter), amount);

        uint256 balanceRaBefore = Asset(ds).balanceOf(DEFAULT_ADDRESS);
        vm.warp(current);

        vm.pauseGasMetering();

        corkConfig.updateAmmBaseFeePercentage(defaultCurrencyId, 1 ether);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        uint256 amountOut = result.amountOut;

        uint256 balanceRaAfter = Asset(address(ds)).balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(balanceRaAfter - balanceRaBefore, amountOut);

        ff_expired();

        // should work even if the resulting lowerbound is very large(won't be gas efficient)
        IDsFlashSwapCore.BuyAprroxParams memory params = defaultBuyApproxParams();
        params.maxFeeIter = 100000;
        params.feeIntervalAdjustment = 1 ether;

        // should work after expiry
        flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, params, defaultOffchainGuessParams());

        // there's no sufficient liquidity due to very low HIYA, so we disable the fee to make it work
        corkConfig.updateAmmBaseFeePercentage(defaultCurrencyId, 0 ether);

        flashSwapRouter.swapRaforDs(currencyId, dsId, 0.01 ether, 0, params, defaultOffchainGuessParams());
    }

    function testFuzz_buyDS(uint256 amount, uint8 raDecimals, uint8 paDecimals) public {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        amount = bound(amount, 0.001 ether, 100 ether);
        amount = TransferHelper.normalizeDecimals(amount, TARGET_DECIMALS, raDecimals);

        ra.approve(address(flashSwapRouter), type(uint256).max);

        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);

        (uint256 raReserve, uint256 ctReserve) = hook.getReserves(address(ra), address(ct));

        // 1-t = 0.1

        Asset(ds).approve(address(flashSwapRouter), amount);

        uint256 balanceDsBefore = Asset(ds).balanceOf(DEFAULT_ADDRESS);
        vm.warp(current);

        // TODO : figure out the out of whack gas consumption
        vm.pauseGasMetering();

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        uint256 amountOut = result.amountOut;

        uint256 balanceDsAfter = Asset(address(ds)).balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(balanceDsAfter - balanceDsBefore, amountOut);

        ff_expired();

        // should work even if the resulting lowerbound is very large(won't be gas efficient)
        IDsFlashSwapCore.BuyAprroxParams memory params = defaultBuyApproxParams();
        params.maxFeeIter = 100000;
        params.feeIntervalAdjustment = 1000 ether;

        (raReserve, ctReserve) = hook.getReserves(address(ra), address(ct));

        // should work after expiry
        flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, params, defaultOffchainGuessParams());

        // there's no sufficient liquidity due to very low HIYA, so we disable the fee to make it work
        corkConfig.updateAmmBaseFeePercentage(defaultCurrencyId, 0 ether);

        (raReserve, ctReserve) = hook.getReserves(address(ra), address(ct));

        amount = TransferHelper.normalizeDecimals(0.001 ether, TARGET_DECIMALS, raDecimals);
        flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, params, defaultOffchainGuessParams());
    }

    /// forge-config: default.fuzz.show-logs = true
    function testFuzz_buyDSWithDsFee(uint8 raDecimals, uint8 paDecimals) public {
        uint256 amount = 1 ether;
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        // 10%
        uint256 feePercentage = 10 ether;
        // set up the necessary fees
        corkConfig.updateRouterDsExtraFee(currencyId, feePercentage);
        corkConfig.updateDsExtraFeeTreasurySplitPercentage(currencyId, feePercentage);
        corkConfig.updateReserveSellPressurePercentage(currencyId, feePercentage);

        amount = TransferHelper.normalizeDecimals(amount, TARGET_DECIMALS, raDecimals);

        ra.approve(address(flashSwapRouter), type(uint256).max);

        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);

        // 1-t = 0.1
        Asset(ds).approve(address(flashSwapRouter), amount);

        vm.warp(current);

        // TODO : figure out the out of whack gas consumption
        vm.pauseGasMetering();

        address treasury = corkConfig.treasury();
        uint256 balanceTreasuryBefore = ra.balanceOf(treasury);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        uint256 expectedFee = 0.01 ether;
        expectedFee = TransferHelper.normalizeDecimals(expectedFee, TARGET_DECIMALS, raDecimals);
        vm.assertEq(result.fee, expectedFee);

        uint256 expectedTreasuryFee = 0.001 ether;
        expectedTreasuryFee = TransferHelper.normalizeDecimals(expectedTreasuryFee, TARGET_DECIMALS, raDecimals);

        uint256 balanceTreasuryAfter = ra.balanceOf(treasury);
        vm.assertEq(balanceTreasuryAfter - balanceTreasuryBefore, expectedTreasuryFee);

        amount = 10 ether;
        amount = TransferHelper.normalizeDecimals(amount, TARGET_DECIMALS, raDecimals);

        result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // the ds trades doesn't go through, fee should be 0
        vm.assertEq(result.fee, 0);

        // the ds trades doesn't go through, treasury balance should be the same
        uint256 balanceTreasury = ra.balanceOf(treasury);
        vm.assertEq(balanceTreasury, balanceTreasuryAfter);
    }

    function testFuzz_buyDsOffchainGuess(uint256 amount, uint8 raDecimals, uint8 paDecimals) public {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        amount = bound(amount, 0.001 ether, 100 ether);
        amount = TransferHelper.normalizeDecimals(amount, TARGET_DECIMALS, raDecimals);

        ra.approve(address(flashSwapRouter), type(uint256).max);

        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);

        (uint256 raReserve, uint256 ctReserve) = hook.getReserves(address(ra), address(ct));

        // 1-t = 0.1

        Asset(ds).approve(address(flashSwapRouter), amount);

        uint256 balanceDsBefore = Asset(ds).balanceOf(DEFAULT_ADDRESS);
        vm.warp(current);

        // TODO : figure out the out of whack gas consumption
        vm.pauseGasMetering();

        snapshotRouterState();

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        IDsFlashSwapCore.OffchainGuess memory offchainGuess;
        offchainGuess.initialBorrowAmount = result.initialBorrow;
        offchainGuess.afterSoldBorrowAmount = result.afterSoldBorrow;

        revertRouterState();

        // should pass
        result = flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, defaultBuyApproxParams(), offchainGuess);
        uint256 amountOut = result.amountOut;

        uint256 balanceDsAfter = Asset(address(ds)).balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(balanceDsAfter - balanceDsBefore, amountOut);

        ff_expired();

        // should work even if the resulting lowerbound is very large(won't be gas efficient)
        IDsFlashSwapCore.BuyAprroxParams memory params = defaultBuyApproxParams();
        params.maxFeeIter = 100000;
        params.feeIntervalAdjustment = 1000 ether;

        (raReserve, ctReserve) = hook.getReserves(address(ra), address(ct));

        // should work after expiry
        snapshotRouterState();

        result = flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, params, defaultOffchainGuessParams());

        offchainGuess.initialBorrowAmount = result.initialBorrow;
        offchainGuess.afterSoldBorrowAmount = result.afterSoldBorrow;

        revertRouterState();
        result = flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, params, offchainGuess);

        // there's no sufficient liquidity due to very low HIYA, so we disable the fee to make it work
        corkConfig.updateAmmBaseFeePercentage(defaultCurrencyId, 0 ether);

        (raReserve, ctReserve) = hook.getReserves(address(ra), address(ct));

        amount = TransferHelper.normalizeDecimals(0.001 ether, TARGET_DECIMALS, raDecimals);

        snapshotRouterState();
        result = flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, params, defaultOffchainGuessParams());

        offchainGuess.initialBorrowAmount = result.initialBorrow;
        offchainGuess.afterSoldBorrowAmount = result.afterSoldBorrow;

        revertRouterState();

        flashSwapRouter.swapRaforDs(currencyId, dsId, amount, 0, params, offchainGuess);
    }

    // ff to expiry and update infos
    function ff_expired() internal {
        // fast forward to expiry
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry);

        uint256 rolloverBlocks = flashSwapRouter.getRolloverEndInBlockNumber(currencyId);
        vm.roll(block.number + rolloverBlocks);

        Asset(ct).approve(address(moduleCore), DEFAULT_DEPOSIT_AMOUNT);

        issueNewDs(currencyId);

        fetchProtocolGeneralInfo();
    }

    function fetchProtocolGeneralInfo() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);
    }
}
