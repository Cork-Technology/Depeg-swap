pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyERCWithPermit} from "./../../contracts/dummy/DummyERCWithPermit.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "./../../contracts/interfaces/IDsFlashSwapRouter.sol";
import "forge-std/console.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FlashSwapTest is Helper {
    DummyERCWithPermit internal ra;
    DummyERCWithPermit internal pa;
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

        (ra, pa, currencyId) = initializeAndIssueNewDsWithRaAsPermit(block.timestamp + 1 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);
        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        ra.approve(address(moduleCore), 100_000_000_000 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0, 0, block.timestamp);

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
            currencyId,
            dsId,
            1 ether,
            0,
            defaultBuyApproxParams(),
            defaultOffchainGuessParams(),
            block.timestamp + 30 minutes
        );

        uint256 amountOut = result.amountOut;

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, true);

        // should fail, not enough liquidity
        vm.expectRevert();
        flashSwapRouter.swapDsforRa(currencyId, dsId, 50 ether, 0, block.timestamp + 30 minutes);

        uint256 lvReserveBefore = flashSwapRouter.getLvReserve(currencyId, dsId);
        // since now the reserve sell is made after the user trades go through, we should always be able to sell the reserve
        result = flashSwapRouter.swapRaforDs(
            currencyId,
            dsId,
            10 ether,
            0,
            defaultBuyApproxParams(),
            defaultOffchainGuessParams(),
            block.timestamp + 30 minutes
        );
        amountOut = result.amountOut;

        uint256 lvReserveAfter = flashSwapRouter.getLvReserve(currencyId, dsId);

        vm.assertLt(lvReserveAfter, lvReserveBefore);
    }

    function test_swapRaForDsShouldHandlePermitCorrectly() public virtual {
        uint256 user1Key = vm.deriveKey("test test test test test test test test test test test junk", 0);
        // Create address from the private key
        address user1 = vm.addr(user1Key);
        address user2 = makeAddr("user2");

        // Give user1 some RA tokens to test with
        vm.deal(user1, 10 ether);
        vm.startPrank(user1);
        ra.deposit{value: 10 ether}();
        vm.stopPrank();

        bytes memory rawRaPermitSig = getPermit(
            user1,
            address(flashSwapRouter),
            10 ether,
            ra.nonces(user1),
            block.timestamp + 100000,
            user1Key,
            ra.DOMAIN_SEPARATOR()
        );

        Asset dsAsset = Asset(ds);

        // Before swap
        uint256 user1RaBalance = ra.balanceOf(user1);
        uint256 user1DsBalance = dsAsset.balanceOf(user1);
        uint256 user2RaBalance = ra.balanceOf(user2);
        uint256 user2DsBalance = dsAsset.balanceOf(user2);

        // Execute the swap
        vm.prank(user2);
        vm.expectRevert();
        flashSwapRouter.swapRaforDs(
            currencyId,
            dsId,
            10 ether,
            0,
            rawRaPermitSig,
            block.timestamp + 100000,
            defaultBuyApproxParams(),
            defaultOffchainGuessParams()
        );

        vm.prank(user1);
        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId,
            dsId,
            10 ether,
            0,
            rawRaPermitSig,
            block.timestamp + 100000,
            defaultBuyApproxParams(),
            defaultOffchainGuessParams()
        );
        uint256 amountOut = result.amountOut;

        // After swap
        vm.assertEq(ra.balanceOf(user1), user1RaBalance - 10 ether);
        vm.assertEq(dsAsset.balanceOf(user1), user1DsBalance + amountOut);
        vm.assertEq(ra.balanceOf(user2), user2RaBalance);
        vm.assertEq(dsAsset.balanceOf(user2), user2DsBalance);
    }

    function test_swapRaForDsShouldHandleWhenPsmAndLvReservesAreZero() public virtual {
        address user = address(0x123456789);
        deal(address(ra), user, 100e18);
        deal(address(pa), user, 100e18);

        vm.startPrank(user);
        ra.approve(address(moduleCore), 100e18);
        // moduleCore.depositPsm(defaultCurrencyId, 1e18);
        moduleCore.depositLv(defaultCurrencyId, 19e18, 0, 0, 0, block.timestamp);

        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, moduleCore.lastDsId(defaultCurrencyId));
        ERC20(ds).approve(address(flashSwapRouter), 1e18);

        ra.approve(address(flashSwapRouter), 100e18);

        IDsFlashSwapCore.BuyAprroxParams memory buyParams;
        buyParams.maxApproxIter = 256;
        buyParams.epsilon = 1e9;
        buyParams.feeIntervalAdjustment = 1e16;
        buyParams.precisionBufferPercentage = 1e16;
        flashSwapRouter.swapRaforDs(
            defaultCurrencyId, 1, 1e18, 0.9e18, buyParams, defaultOffchainGuessParams(), block.timestamp + 30 minutes
        );
        flashSwapRouter.swapRaforDs(
            defaultCurrencyId, 1, 1e18, 0.9e18, buyParams, defaultOffchainGuessParams(), block.timestamp + 30 minutes
        );

        vm.startPrank(DEFAULT_ADDRESS);
        vm.warp(block.timestamp + 100 days);
        corkConfig.issueNewDs(defaultCurrencyId, block.timestamp + 10 seconds);

        ERC20 lv = ERC20(moduleCore.lvAsset(defaultCurrencyId));
        lv.approve(address(moduleCore), lv.balanceOf(address(DEFAULT_ADDRESS)));
        IVault.RedeemEarlyParams memory redeemParams = IVault.RedeemEarlyParams(
            defaultCurrencyId, lv.balanceOf(address(DEFAULT_ADDRESS)), 0, block.timestamp + 10 seconds, 0, 0, 0
        );
        moduleCore.redeemEarlyLv(redeemParams);

        vm.startPrank(user);
        lv.approve(address(moduleCore), lv.balanceOf(address(user)));

        redeemParams = IVault.RedeemEarlyParams(
            defaultCurrencyId, lv.balanceOf(address(user)), 0, block.timestamp + 10 seconds, 0, 0, 0
        );
        moduleCore.redeemEarlyLv(redeemParams);

        flashSwapRouter.swapRaforDs(
            defaultCurrencyId, 2, 1e3, 1, buyParams, defaultOffchainGuessParams(), block.timestamp + 30 minutes
        );
    }
}
