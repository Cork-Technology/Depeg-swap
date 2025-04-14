// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "../../Helper.sol";
import {DummyWETH} from "../../../../contracts/dummy/DummyWETH.sol";
import {Asset} from "../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "../../../../contracts/libraries/Pair.sol";
import {IPSMcore} from "../../../../contracts/interfaces/IPSMcore.sol";
import {IDsFlashSwapCore} from "../../../../contracts/interfaces/IDsFlashSwapRouter.sol";
import {IErrors} from "../../../../contracts/interfaces/IErrors.sol";
import {CorkConfig} from "../../../../contracts/core/CorkConfig.sol";
import {UD60x18, convert as convertUd, ud, unwrap} from "@prb/math/src/UD60x18.sol";

contract ReserveSellPressureTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    address ct;
    address ds;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;

    uint256 end = block.timestamp + 10 days;
    uint256 current = block.timestamp + 1 days;

    uint256 public dsId;

    address public nonManager = makeAddr("nonManager");

    // Constants for sell pressure calculation
    uint256 internal constant SELL_PRESSURE_CAP = 97.5 ether;

    function defaultInitialArp() internal pure virtual override returns (uint256) {
        return 5 ether;
    }

    function defaultExchangeRate() internal pure virtual override returns (uint256) {
        return 1.1 ether;
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

        corkConfig.updateRouterGradualSaleStatus(currencyId, false);
        vm.stopPrank();
    }

    function test_UpdateReserveSellPressurePercentage() public {
        vm.startPrank(DEFAULT_ADDRESS);


        // Should be able to update as the manager
        vm.expectEmit(true, true, false, true);
        emit IDsFlashSwapCore.ReserveSellPressurePercentageUpdated(currencyId, 1 ether);
        corkConfig.updateReserveSellPressurePercentage(currencyId, 1 ether);

        assertEq(flashSwapRouter.getReserveSellPressurePercentageThresold(currencyId), 1 ether);

        // Verify the effect by seeing its impact on a swap
        ra.approve(address(flashSwapRouter), type(uint256).max);
        uint256 amount = 0.01 ether;

        vm.warp(current);

        // With 10% threshold, we expect a moderate sell pressure
        IDsFlashSwapCore.SwapRaForDsReturn memory result1 = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Update to a higher threshold (should decrease sell pressure)
        corkConfig.updateReserveSellPressurePercentage(currencyId, 20 ether);

        IDsFlashSwapCore.SwapRaForDsReturn memory result2 = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Verify sell pressure is greater with lower threshold
        assertGt(result1.reserveSellPressure, result2.reserveSellPressure);
        vm.stopPrank();
    }

    function test_UpdateReserveSellPressurePercentageAccessControl() public {
        // Should revert when called by non-manager
        vm.startPrank(nonManager);

        vm.expectRevert(CorkConfig.CallerNotManager.selector);
        corkConfig.updateReserveSellPressurePercentage(currencyId, 15 ether);

        // Should revert when calling router directly from unauthorized account
        vm.expectRevert(IErrors.NotConfig.selector);
        flashSwapRouter.updateReserveSellPressurePercentage(currencyId, 15 ether);
        vm.stopPrank();
    }

    function test_ExtremeReserveSellPressureValuesBothWays() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Test with very low threshold
        corkConfig.updateReserveSellPressurePercentage(currencyId, 0.01 ether);

        ra.approve(address(flashSwapRouter), type(uint256).max);
        uint256 amount = 0.01 ether;
        vm.warp(current);

        IDsFlashSwapCore.SwapRaForDsReturn memory result1 = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Should be very high sell pressure (97.5%)
        assertEq(result1.reserveSellPressure, SELL_PRESSURE_CAP);

        // Test with very high threshold
        corkConfig.updateReserveSellPressurePercentage(currencyId, 100 ether);

        IDsFlashSwapCore.SwapRaForDsReturn memory result2 = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // For verification, should be less than 5.5%
        assertLt(result2.reserveSellPressure, 5.5 ether);
        vm.stopPrank();
    }

    function test_ZeroReserveSellPressureThreshold() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Update to minimum 0.01 (edge case)
        corkConfig.updateReserveSellPressurePercentage(currencyId, 1e16);

        ra.approve(address(flashSwapRouter), type(uint256).max);
        uint256 amount = 0.01 ether;
        vm.warp(current);

        // Should still work, with maximum sell pressure
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Should be maximum sell pressure
        assertEq(result.reserveSellPressure, SELL_PRESSURE_CAP);
        vm.stopPrank();
    }
}
