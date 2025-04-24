// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "../../Helper.sol";
import {DummyWETH} from "../../../../contracts/dummy/DummyWETH.sol";
import {Asset} from "../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "../../../../contracts/libraries/Pair.sol";
import {IPSMcore} from "../../../../contracts/interfaces/IPSMcore.sol";
import {IDsFlashSwapCore} from "../../../../contracts/interfaces/IDsFlashSwapRouter.sol";
import {IErrors} from "../../../../contracts/interfaces/IErrors.sol";
import {RouterState} from "../../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {IVault} from "../../../../contracts/interfaces/IVault.sol";
import {TransferHelper} from "../../../../contracts/libraries/TransferHelper.sol";

contract DsReserveSellTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    address ct;
    address ds;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;

    uint256 end = block.timestamp + 10 days;
    uint256 current = block.timestamp + 1 days;

    uint256 public dsId;

    // For tracking router behavior
    uint256 stateId;

    function setUp() public virtual {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(end);

        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);

        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        ra.approve(address(moduleCore), 100_000_000_000 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0, 0);

        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);

        corkConfig.updateRouterGradualSaleStatus(currencyId, false);
        vm.stopPrank();
    }

    function snapshotRouterState() internal {
        stateId = vm.snapshot();
    }

    function revertRouterState() internal {
        vm.revertTo(stateId);
    }

    // Test that the reserve sell works when the AMM liquidity is reduced with 97.5% sell pressure
    function test_SellFromReserveWorkWhenAMMLiquidityIsReduced() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Setup the test to trigger a reserve sell
        ra.approve(address(flashSwapRouter), type(uint256).max);
        Asset(ds).approve(address(moduleCore), type(uint256).max);
        uint256 reserveAmount = flashSwapRouter.getLvReserve(currencyId, dsId);

        // Set reserve pressure threshold
        corkConfig.updateReserveSellPressurePercentage(currencyId, 1 ether); // Very low threshold to ensure sell pressure

        // Decrease the amount of CT in the AMM
        Asset(ct).approve(address(hook), type(uint256).max);
        uint256 amountIn = hook.getAmountIn(address(ra), address(ct), false, 500 ether);
        uint256 amountOut = hook.getAmountOut(address(ra), address(ct), false, amountIn) - 1 gwei;
        hook.swap(address(ra), address(ct), amountOut / 2, 0, "");

        uint256 amount = 9 ether;
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Verify the swap worked and returned the expected DS tokens
        assertGt(result.amountOut, 0, "Swap should return DS tokens");
        assertEq(result.reserveSellPressure, 97.5 ether, "Sell pressure should be less than 97.5 ether");

        // Check if LV reserve decreased (reserve sell succeeded)
        uint256 reserveAfter = flashSwapRouter.getLvReserve(currencyId, dsId);
        bool sellSucceeded = reserveAfter < reserveAmount;
        assertEq(sellSucceeded, true, "Sell should be succeeded");
        vm.stopPrank();
    }

    // Test that the reserve sell works when the DS reserve sell fails
    // We increased price of CT so that DS reserve sell fails
    function test_SellFromReserveWorkWhenDsReserveSellFails() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Setup the test to trigger a reserve sell
        ra.approve(address(flashSwapRouter), type(uint256).max);
        Asset(ds).approve(address(moduleCore), type(uint256).max);
        uint256 reserveAmount = flashSwapRouter.getLvReserve(currencyId, dsId);

        // Set reserve pressure threshold to 100% to ensure sell pressure
        corkConfig.updateReserveSellPressurePercentage(currencyId, 100 ether);

        // Buy maximum CT and increase CT prices to the moon
        ra.approve(address(hook), type(uint256).max);
        uint256 amountIn = hook.getAmountIn(address(ra), address(ct), false, 510 ether);
        uint256 amountOut = hook.getAmountOut(address(ra), address(ct), false, amountIn);
        hook.swap(address(ra), address(ct), 0, amountOut / 2, "");
        hook.swap(address(ra), address(ct), 0, amountOut / 2, "");
        hook.swap(address(ra), address(ct), 0, 2.1 ether, "");
        hook.swap(address(ra), address(ct), 0, 0.2 ether, "");
        hook.swap(address(ra), address(ct), 0, 0.1 ether, "");
        hook.swap(address(ra), address(ct), 0, 0.1 ether, "");
        hook.swap(address(ra), address(ct), 0, 0.1 ether, "");

        uint256 ctPrice = hook.getAmountOut(address(ra), address(ct), false, 1 ether);
        assertGt(ctPrice, 1 ether, "CT price should be greater than 1 ether");

        uint256 amount = 100 ether;
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Verify the swap worked and returned the expected DS tokens
        assertGt(result.amountOut, 0, "Swap should return DS tokens");
        assertEq(result.reserveSellPressure, 0, "Sell pressure should be zero");

        // Check if LV reserve decreased (reserve sell succeeded)
        uint256 reserveAfter = flashSwapRouter.getLvReserve(currencyId, dsId);
        bool sellSucceeded = reserveAfter < reserveAmount;
        assertEq(sellSucceeded, false, "Sell should be failed");
        vm.stopPrank();
    }

    // Test that the reserve sell reverts when the reserve is zero
    function test_SellFromReserveWithZeroReserveShouldRevert() public {
        vm.startPrank(DEFAULT_ADDRESS);

        (ra, pa, currencyId) = initializeAndIssueNewDs(end);
        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        // Set reserve pressure threshold
        corkConfig.updateReserveSellPressurePercentage(currencyId, 0.01 ether);

        // We don't add anything to reserves, so reserve is zero
        assertEq(flashSwapRouter.getLvReserve(currencyId, dsId), 0, "LV reserve should be zero");
        assertEq(flashSwapRouter.getPsmReserve(currencyId, dsId), 0, "PSM reserve should be zero");

        ra.approve(address(flashSwapRouter), type(uint256).max);
        uint256 amount = 0.01 ether;

        // Since there's no reserve, swapRaforDs should essentially revert with InvalidPoolStateOrNearExpired
        vm.expectRevert(IErrors.InvalidPoolStateOrNearExpired.selector);
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        vm.stopPrank();
    }

    // Test that AMM reserves are updated correctly after a swapRaforDs call
    // When the reserve sell pressure is set to 0%
    function test_AmmReservesAfterSwapRaforDs() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Setup for swap
        ra.approve(address(flashSwapRouter), type(uint256).max);

        // Get initial AMM reserves
        (uint256 raReserveBefore, uint256 ctReserveBefore) = hook.getReserves(address(ra), address(ct));

        // Get initial price ratios
        (uint256 raPriceRatioBefore, uint256 ctPriceRatioBefore) =
            flashSwapRouter.getCurrentPriceRatio(currencyId, dsId);

        // Perform the swap
        uint256 amount = 5 ether;
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Get reserves after swap
        (uint256 raReserveAfter, uint256 ctReserveAfter) = hook.getReserves(address(ra), address(ct));

        // Get price ratios after swap
        (uint256 raPriceRatioAfter, uint256 ctPriceRatioAfter) = flashSwapRouter.getCurrentPriceRatio(currencyId, dsId);

        // Verify RA reserve increased (more RA in pool)
        assertGt(raReserveAfter, raReserveBefore, "RA reserve should increase");

        // Verify CT reserve decreased (CT was taken out)
        assertLt(ctReserveAfter, ctReserveBefore, "CT reserve should decrease");

        // Price ratios should reflect the changed reserves
        // More RA relative to CT means lower RA/CT ratio and higher CT/RA ratio
        assertLt(raPriceRatioAfter, raPriceRatioBefore, "RA/CT price ratio should decrease");
        assertGt(ctPriceRatioAfter, ctPriceRatioBefore, "CT/RA price ratio should increase");

        vm.stopPrank();
    }

    // Test that AMM reserves are updated correctly after a swapRaforDs call
    // When the reserve sell pressure is set to 50%
    function test_AmmReservesAfterSwapRaforDsWith50PercentReserveSellPressure() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Setup for swap
        ra.approve(address(flashSwapRouter), type(uint256).max);

        // Get initial AMM reserves
        (uint256 raReserveBefore, uint256 ctReserveBefore) = hook.getReserves(address(ra), address(ct));

        // Get initial price ratios
        (uint256 raPriceRatioBefore, uint256 ctPriceRatioBefore) =
            flashSwapRouter.getCurrentPriceRatio(currencyId, dsId);

        // Set reserve pressure threshold to 50%
        corkConfig.updateReserveSellPressurePercentage(currencyId, 50 ether);

        // Perform the swap
        uint256 amount = 5 ether;
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Get reserves after swap
        (uint256 raReserveAfter, uint256 ctReserveAfter) = hook.getReserves(address(ra), address(ct));

        // Get price ratios after swap
        (uint256 raPriceRatioAfter, uint256 ctPriceRatioAfter) = flashSwapRouter.getCurrentPriceRatio(currencyId, dsId);

        // Verify RA reserve decreased (less RA in pool)
        assertLt(raReserveAfter, raReserveBefore, "RA reserve should decrease");

        // Verify CT reserve increased (CT was added to the pool)
        assertGt(ctReserveAfter, ctReserveBefore, "CT reserve should increase");

        // Price ratios should reflect the changed reserves
        // More CT relative to RA means ct price ratio decreases and ra price ratio increases
        assertLt(ctPriceRatioAfter, ctPriceRatioBefore, "CT/RA price ratio should decrease");
        assertGt(raPriceRatioAfter, raPriceRatioBefore, "RA/CT price ratio should increase");

        vm.stopPrank();
    }

    // Test AMM state for large swaps
    function test_AmmStateAfterLargeSwapRaforDs() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Set reserve pressure threshold to 100%
        corkConfig.updateReserveSellPressurePercentage(currencyId, 100 ether);

        // Setup for swap
        ra.approve(address(flashSwapRouter), type(uint256).max);

        // Get initial AMM reserves
        (uint256 raReserveBefore, uint256 ctReserveBefore) = hook.getReserves(address(ra), address(ct));

        // Get initial price ratios
        (uint256 raPriceRatioBefore, uint256 ctPriceRatioBefore) =
            flashSwapRouter.getCurrentPriceRatio(currencyId, dsId);

        // Large swap (50x the previous test and 10% of the total reserve)
        uint256 amount = 250 ether;
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Get reserves after swap
        (uint256 raReserveAfter, uint256 ctReserveAfter) = hook.getReserves(address(ra), address(ct));

        // Get price ratios after swap
        (uint256 raPriceRatioAfter, uint256 ctPriceRatioAfter) = flashSwapRouter.getCurrentPriceRatio(currencyId, dsId);

        // With larger swaps, price impact should be more significant
        assertGt(raReserveBefore - raReserveAfter, amount * 95 / 100, "RA reserve should decrease significantly");
        // CT reserve should increase as buying DS will decrease the price of CT
        assertGt(ctReserveAfter, ctReserveBefore, "CT reserve should increase");

        // Price impact should be larger with bigger swaps
        assertGt(raPriceRatioAfter, raPriceRatioBefore, "RA/CT price ratio should increase more significantly");
        assertLt(ctPriceRatioAfter, ctPriceRatioBefore, "CT/RA price ratio should decrease more significantly");

        // Get the price impact percentage
        uint256 priceRatioChange = (raPriceRatioAfter - raPriceRatioBefore) * 100 / raPriceRatioBefore;

        // Larger swaps should have meaningful price impact
        assertGt(priceRatioChange, 5, "Large swap should have meaningful price impact");

        vm.stopPrank();
    }
}
