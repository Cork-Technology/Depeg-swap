pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "./../../contracts/interfaces/IDsFlashSwapRouter.sol";
import "forge-std/console.sol";

contract FlashSwapTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;

    uint256 public dsId;

    address public ct;
    address public ds;

    function defaultInitialArp() internal pure virtual override returns (uint256) {
        return 5 ether;
    }

    function setUp() public virtual {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 1 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);
        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        ra.approve(address(moduleCore), 100_000_000_000 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0);

        // save initial data
        fetchProtocolGeneralInfo();
    }

    function fetchProtocolGeneralInfo() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);
    }

    function test_buyBack() public virtual {
        uint256 prevDsId = dsId;

        ra.approve(address(flashSwapRouter), type(uint256).max);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, 1 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        uint256 amountOut = result.amountOut;

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, true);

        // should fail, not enough liquidity
        vm.expectRevert();
        flashSwapRouter.swapDsforRa(currencyId, dsId, 50 ether, 0);

        // should work, even though there's insfuicient liquidity to sell the LV reserves
        uint256 lvReserveBefore = flashSwapRouter.getLvReserve(currencyId, dsId);

        result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, 100 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        amountOut = result.amountOut;

        uint256 lvReserveAfter = flashSwapRouter.getLvReserve(currencyId, dsId);

        vm.assertEq(lvReserveBefore, lvReserveAfter);

        uint256 raBalanceBefore = ra.balanceOf(DEFAULT_ADDRESS);
        Asset(ds).approve(address(flashSwapRouter), 1000 ether);
        uint256 amountOutSell = flashSwapRouter.swapDsforRa(currencyId, dsId, 50 ether, 0);
        uint256 raBalanceAfter = ra.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(raBalanceAfter, raBalanceBefore + amountOutSell);

        // add more liquidity to the router and AMM
        moduleCore.depositLv(currencyId, 10_000 ether, 0, 0);

        // now if buy, it should sell from reserves
        lvReserveBefore = flashSwapRouter.getLvReserve(currencyId, dsId);
        result = flashSwapRouter.swapRaforDs(currencyId, dsId, 10 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams());
        amountOut = result.amountOut;

        lvReserveAfter = flashSwapRouter.getLvReserve(currencyId, dsId);

        vm.assertTrue(lvReserveAfter < lvReserveBefore);
    }

    function test_swapRaForDsShouldHandleWhenPsmAndLvReservesAreZero() public virtual {
        address user = address(0x123456789);
        deal(address(ra), user, 100e18);
        deal(address(pa), user, 100e18);

        vm.startPrank(user);
        ra.approve(address(moduleCore), 100e18);
        // moduleCore.depositPsm(defaultCurrencyId, 1e18);
        moduleCore.depositLv(defaultCurrencyId, 19e18, 0, 0);

        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, moduleCore.lastDsId(defaultCurrencyId));
        ERC20(ds).approve(address(flashSwapRouter), 1e18);

        ra.approve(address(flashSwapRouter), 100e18);

        IDsFlashSwapCore.BuyAprroxParams memory buyParams;
        buyParams.maxApproxIter = 256;
        buyParams.epsilon = 1e9;
        buyParams.feeIntervalAdjustment = 1e16; 
        buyParams.precisionBufferPercentage = 1e16;
        flashSwapRouter.swapRaforDs(defaultCurrencyId, 1, 1e18, 0.9e18, buyParams);
        flashSwapRouter.swapRaforDs(defaultCurrencyId, 1, 1e18, 0.9e18, buyParams);

        vm.startPrank(DEFAULT_ADDRESS);
        vm.warp(block.timestamp + 100 days);
        corkConfig.issueNewDs(defaultCurrencyId, DEFAULT_EXCHANGE_RATES, DEFAULT_REPURCHASE_FEE, DEFAULT_DECAY_DISCOUNT_RATE, DEFAULT_ROLLOVER_PERIOD, block.timestamp + 10 seconds);

        ERC20 lv = ERC20(moduleCore.lvAsset(defaultCurrencyId));
        lv.approve(address(moduleCore), lv.balanceOf(address(DEFAULT_ADDRESS)));
        IVault.RedeemEarlyParams memory redeemParams  = IVault.RedeemEarlyParams(
            defaultCurrencyId, 
            lv.balanceOf(address(DEFAULT_ADDRESS)),
            0,
            block.timestamp + 10 seconds
        );
        moduleCore.redeemEarlyLv(redeemParams);

        vm.startPrank(user);
        lv.approve(address(moduleCore), 19e18);

        redeemParams  = IVault.RedeemEarlyParams(
            defaultCurrencyId, 
            lv.balanceOf(address(user)),
            0,
            block.timestamp + 10 seconds
        );
        moduleCore.redeemEarlyLv(redeemParams);

        flashSwapRouter.swapRaforDs(defaultCurrencyId, 2, 1e3, 1, buyParams);
    }
}
