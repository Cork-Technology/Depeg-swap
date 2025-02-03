pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MathHelper} from "./../../contracts/libraries/MathHelper.sol";

contract DsPaRedeemTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 10000 ether;
    uint256 redemptionFeePercentage = 1 ether;
    uint256 treasurySplit = 10 ether;

    uint256 public dsId;

    address public lv;
    address user2 = address(30);
    address ds;
    uint256 _expiry = 1 days;
    uint256 start;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(_expiry, redemptionFeePercentage);
        corkConfig.updatePsmRepurchaseFeePercentage(defaultCurrencyId, redemptionFeePercentage);
        vm.deal(DEFAULT_ADDRESS, type(uint256).max);

        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), type(uint256).max);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);

        // save initial data
        lv = assetFactory.getLv(address(ra), address(pa), _expiry);
        dsId = moduleCore.lastDsId(currencyId);
        (, ds) = moduleCore.swapAsset(currencyId, 1);
        Asset(ds).approve(address(moduleCore), type(uint256).max);
        pa.approve(address(moduleCore), type(uint256).max);
        start = Asset(ds).issuedAt();

        // 10% treasury split
        corkConfig.updatePsmBaseRedemptionFeeTreasurySplitPercentage(defaultCurrencyId, treasurySplit);
        corkConfig.updatePsmRepurchaseFeeTreasurySplitPercentage(defaultCurrencyId, treasurySplit);
    }

    function testFuzz_redeemRepurchases(uint256 redeemAmount) external {
        redeemAmount = bound(redeemAmount, 0.1 ether, DEFAULT_DEPOSIT_AMOUNT);

        uint256 expectedFee = MathHelper.calculatePercentageFee(moduleCore.baseRedemptionFee(currencyId), redeemAmount);
        uint256 expectedTreasuryBalance = MathHelper.calculatePercentageFee(treasurySplit, expectedFee);

        uint256 received;
        uint256 fee;
        (received,, fee,) = moduleCore.redeemRaWithDsPa(currencyId, dsId, redeemAmount);
        vm.assertEq(received, redeemAmount - expectedFee);
        vm.assertEq(fee, expectedFee);

        uint256 treasuryBalance = ra.balanceOf(CORK_PROTOCOL_TREASURY);
        vm.assertEq(treasuryBalance, expectedTreasuryBalance);

        // for t = 1
        vm.warp(start);
        (,,,, fee,) = moduleCore.repurchase(defaultCurrencyId, redeemAmount);
        vm.assertApproxEqAbs(fee, expectedFee, 0.1 ether);

        uint256 treasuryBalanceAfter = ra.balanceOf(CORK_PROTOCOL_TREASURY);

        vm.assertApproxEqAbs(treasuryBalanceAfter - treasuryBalance, expectedTreasuryBalance, 0.01 ether);
    }
}
