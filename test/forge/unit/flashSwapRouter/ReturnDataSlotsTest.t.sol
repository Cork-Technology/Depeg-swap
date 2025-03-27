// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "../../Helper.sol";
import {DummyWETH} from "../../../../contracts/dummy/DummyWETH.sol";
import {Asset} from "../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "../../../../contracts/libraries/Pair.sol";
import {IPSMcore} from "../../../../contracts/interfaces/IPSMcore.sol";
import {IDsFlashSwapCore} from "../../../../contracts/interfaces/IDsFlashSwapRouter.sol";
import {IErrors} from "../../../../contracts/interfaces/IErrors.sol";
import {ReturnDataSlotLib} from "../../../../contracts/libraries/ReturnDataSlotLib.sol";
import {RouterState} from "../../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {CorkConfig} from "../../../../contracts/core/CorkConfig.sol";
import {SlotAccessor} from "../../utils/SlotAcessor.sol";

contract ReturnDataSlotsTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    address ct;
    address ds;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;

    uint256 end = block.timestamp + 10 days;
    uint256 current = block.timestamp + 1 days;

    uint256 public dsId;

    // Helper contract to directly access slots
    SlotAccessor internal slotAccessor;

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

        // Deploy a helper contract to access transient storage slots
        slotAccessor = new SlotAccessor();

        vm.stopPrank();
    }

    function test_ReturnSlotBuyOperation() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Check that the buy slot is initially zero
        assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_BUY), 0);

        // Perform a RA to DS swap
        ra.approve(address(flashSwapRouter), type(uint256).max);
        uint256 amount = 0.5 ether;
        vm.warp(current);
        uint256 dsBalanceBefore = Asset(ds).balanceOf(DEFAULT_ADDRESS);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Verify the DS amount we received from the swap
        uint256 dsBalanceAfter = Asset(ds).balanceOf(DEFAULT_ADDRESS);

        // Verify the slot is reset to zero after the operation
        // (due to autoClearReturnData modifier)
        assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_BUY), 0);

        // The result.amountOut should match the DS balance we received
        assertEq(result.amountOut, dsBalanceAfter - dsBalanceBefore);

        vm.stopPrank();
    }

    function test_ReturnSlotSellOperation() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // First do a buy to get DS tokens
        ra.approve(address(flashSwapRouter), type(uint256).max);
        uint256 buyAmount = 0.5 ether;
        vm.warp(current);

        IDsFlashSwapCore.SwapRaForDsReturn memory buyResult = flashSwapRouter.swapRaforDs(
            currencyId, dsId, buyAmount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        // Check that the sell slot is initially zero
        assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_SELL), 0);

        // Get DS balance
        uint256 dsBalance = Asset(ds).balanceOf(DEFAULT_ADDRESS);
        assertGt(dsBalance, 0, "Should have DS tokens to sell");

        // Approve DS for selling
        Asset(ds).approve(address(flashSwapRouter), dsBalance);

        // Record initial RA balance
        uint256 raBalanceBefore = ra.balanceOf(DEFAULT_ADDRESS);

        // Perform a DS to RA swap (sell)
        uint256 sellAmount = dsBalance / 100; // Sell 1% of the DS tokens
        uint256 amountOut = flashSwapRouter.swapDsforRa(currencyId, dsId, sellAmount, 0);

        // Verify the RA amount we received from the swap
        uint256 raBalanceAfter = ra.balanceOf(DEFAULT_ADDRESS);
        uint256 raReceived = raBalanceAfter - raBalanceBefore;

        // Verify the slot is reset to zero after the operation
        // (due to autoClearReturnData modifier)
        assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_SELL), 0);

        // The amountOut should match the RA we received
        assertEq(amountOut, raReceived);

        vm.stopPrank();
    }

    function test_MultipleOperationsSlotClearing() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Do multiple buy operations to ensure slots are properly cleared between operations
        ra.approve(address(flashSwapRouter), type(uint256).max);

        for (uint256 i = 0; i < 3; i++) {
            // Clear slots check before operation
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_BUY), 0);
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_SELL), 0);
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.REFUNDED_SLOT), 0);
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.DS_FEE_AMOUNT), 0);

            // Perform a swap
            uint256 amount = 0.1 ether * (i + 1); // Different amounts
            vm.warp(current);

            IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
                currencyId, dsId, amount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
            );

            // Slots should be cleared after operation
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_BUY), 0);
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.RETURN_SLOT_SELL), 0);
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.REFUNDED_SLOT), 0);
            assertEq(slotAccessor.getSlotValue(ReturnDataSlotLib.DS_FEE_AMOUNT), 0);
        }

        vm.stopPrank();
    }
}
