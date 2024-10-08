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

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 40_000 ether;
    uint256 internal constant MERRYL_LYNCH_DEFAULT_INITIAL_DS_PRICE = 0.005 ether;

    uint256 public dsId;

    address public ct;
    address public ds;

    function defaultInitialDsPrice() internal pure virtual override returns (uint256) {
        return MERRYL_LYNCH_DEFAULT_INITIAL_DS_PRICE;
    }

    function setUp() public virtual {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 1 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);
        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        // 10000 for psm 10000 for LV
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

    // ff to expiry and update infos
    function ff_expired() internal {
        // fast forward to expiry
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry);

        uint256 rolloverBlocks = flashSwapRouter.getRolloverEndInBlockNumber(currencyId);
        vm.roll(block.number + rolloverBlocks);

        Asset(ct).approve(address(moduleCore), DEFAULT_DEPOSIT_AMOUNT);

        issueNewDs(currencyId, block.timestamp + 1 days);

        fetchProtocolGeneralInfo();
    }

    function test_buyBack() public virtual {
        uint256 prevDsId = dsId;
        uint256 amountOutMin = flashSwapRouter.previewSwapRaforDs(currencyId, dsId, 1 ether);

        ra.approve(address(flashSwapRouter), type(uint256).max);

        uint256 amountOut = flashSwapRouter.swapRaforDs(currencyId, dsId, 1 ether, 0);
        uint256 hpaCummulated = flashSwapRouter.getHpaCumulated(currencyId);
        uint256 vhpaCummulated = flashSwapRouter.getVhpaCumulated(currencyId);

        // we fetch the hpa after expiry so that it's calculated
        uint256 hpa = flashSwapRouter.getHpa(currencyId);

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, DEFAULT_ADDRESS, true);

        amountOutMin = flashSwapRouter.previewSwapRaforDs(currencyId, dsId, 0.1 ether);

        // should fail, not enough liquidity
        vm.expectRevert();
        uint256 amountOutSell = flashSwapRouter.previewSwapDsforRa(currencyId, dsId, 1000 ether);

        // should work, even though there's insfuicient liquidity to sell the LV reserves
        uint256 lvReserveBefore = flashSwapRouter.getLvReserve(currencyId, dsId);
        amountOutMin = flashSwapRouter.previewSwapRaforDs(currencyId, dsId, 100 ether);
        amountOut = flashSwapRouter.swapRaforDs(currencyId, dsId, 100 ether, amountOutMin);
        uint256 lvReserveAfter = flashSwapRouter.getLvReserve(currencyId, dsId);

        vm.assertEq(lvReserveBefore, lvReserveAfter);
        vm.assertEq(amountOut, amountOutMin);

        uint256 raBalanceBefore = ra.balanceOf(DEFAULT_ADDRESS);
        Asset(ds).approve(address(flashSwapRouter), 1000 ether);
        amountOutSell = flashSwapRouter.swapDsforRa(currencyId, dsId, 1000 ether, 0);
        uint256 raBalanceAfter = ra.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(raBalanceAfter, raBalanceBefore + amountOutSell);

        // add more liquidity to the router and AMM
        moduleCore.depositLv(currencyId, 10_000 ether, 0, 0);

        // now if buy, it should sell from reserves
        lvReserveBefore = flashSwapRouter.getLvReserve(currencyId, dsId);
        uint256 previewAmountOut = flashSwapRouter.previewSwapRaforDs(currencyId, dsId, 10 ether);
        amountOut = flashSwapRouter.swapRaforDs(currencyId, dsId, 10 ether, 0);
        lvReserveAfter = flashSwapRouter.getLvReserve(currencyId, dsId);

        vm.assertTrue(lvReserveAfter < lvReserveBefore);
    }
}