pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultRedeemTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 10000 ether;

    uint256 public dsId;

    address public lv;
    address user2 = address(30);

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 1 days, 1 ether);
        vm.deal(DEFAULT_ADDRESS, type(uint256).max);

        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        vm.stopPrank();
        vm.startPrank(user2);

        vm.deal(user2, type(uint256).max);
        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        vm.stopPrank();
        vm.startPrank(DEFAULT_ADDRESS);

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), type(uint256).max);

        // moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0);

        // save initial data
        lv = assetFactory.getLv(address(ra), address(pa));
        dsId = moduleCore.lastDsId(currencyId);
    }

    function test_redeemEarly() external {
        // we first deposit a lot of RA to LV
        moduleCore.depositLv(currencyId, 1_000_000_000 ether, 0, 0);

        //now we buy a lot of DS to accrue value to LV holders
        ra.approve(address(flashSwapRouter), type(uint256).max);
        flashSwapRouter.swapRaforDs(currencyId, dsId, 10_000_000 ether, 0);

        // now we try redeem early
        IERC20(lv).approve(address(moduleCore), 0.9 ether);
        uint256 balanceBefore = IERC20(ra).balanceOf(DEFAULT_ADDRESS);

        (uint256 received, uint256 fee, uint256 feePercentage) =
            moduleCore.redeemEarlyLv(currencyId, DEFAULT_ADDRESS, 0.9 ether, 0, block.timestamp);

        vm.assertTrue(received > 0.9 ether, "should accrue value");

        vm.stopPrank();
        vm.startPrank(user2);

        // deposit first
        ra.approve(address(moduleCore), type(uint256).max);
        uint256 lvReceived = moduleCore.depositLv(currencyId, 1 ether, 0, 0);

        (received, fee, feePercentage) = moduleCore.previewRedeemEarlyLv(currencyId, lvReceived);

        // redeem early
        IERC20(lv).approve(address(moduleCore), 1 ether);
        (received, fee, feePercentage) = moduleCore.redeemEarlyLv(currencyId, DEFAULT_ADDRESS, lvReceived, 0, block.timestamp);

        // user shouldn't accrue any value, so they will receive their original deposits back
        // not exactly 1 ether cause of uni v2 minimum liquidity
        vm.assertApproxEqAbs(received, 1 ether, 1e9);
        // save initial data
    }

    function test_reissueMany() external {
        for (uint256 i = 0; i < 100; i++) {
            ff_expired();
        }
    }

    function defaultExchangeRate() internal pure override returns (uint256) {
        return 1.5 ether;
    }

    function ff_expired() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (address ct,) = moduleCore.swapAsset(currencyId, dsId);
        uint256 expiry = Asset(ct).expiry();

        vm.warp(expiry);

        issueNewDs(currencyId, block.timestamp + 1 days);
    }
}
