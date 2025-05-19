pragma solidity ^0.8.24;

import "./../../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./../../Helper.sol";
import {DummyWETH} from "./../../../../contracts/dummy/DummyWETH.sol";
import "./../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../../../contracts/libraries/Pair.sol";
import "./../../../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";
import "./../../../../contracts/interfaces/IErrors.sol";
import "./../../../../contracts/interfaces/IErrors.sol";

contract VaultLiquidityFundsTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;

    uint256 public dsId;

    address public ct;
    address public ds;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 70 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000 ether);
        ra.deposit{value: 100000 ether}();
        pa.deposit{value: 100000 ether}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), 100_000_000 ether);
        pa.approve(address(moduleCore), 100_000_000 ether);

        corkConfig.updateLvStrategyCtSplitPercentage(currencyId, 50 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0, 0, block.timestamp);

        corkConfig.whitelist(DEFAULT_ADDRESS);
        vm.warp(block.timestamp + 10 days);

        // save initial data
        fetchProtocolGeneralInfo();
    }

    function fetchProtocolGeneralInfo() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);
    }

    function caller() internal returns (address caller) {
        (, caller,) = vm.readCallers();
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
    }

    function test_revertNoFunds() external {
        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertEq(fundsAvailable, 0);

        vm.expectRevert(IErrors.InsufficientFunds.selector);
        moduleCore.requestLiquidationFunds(currencyId, 1 ether, caller());
    }

    function test_requestAfterExpiries() external {
        // we redeem 1000 RA first first
        Asset(ds).approve(address(moduleCore), 1000 ether);
        moduleCore.redeemRaWithDsPa(currencyId, dsId, 1000 ether);

        ff_expired();

        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertTrue(fundsAvailable > 0);

        moduleCore.requestLiquidationFunds(currencyId, fundsAvailable, caller());

        fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);
        vm.assertEq(fundsAvailable, 0);
    }

    function test_revertNotWhiteListed() external {
        vm.stopPrank();

        vm.expectRevert(IErrors.OnlyWhiteListed.selector);
        moduleCore.requestLiquidationFunds(currencyId, 1 ether, caller());
    }

    function test_receiveFunds() external {
        uint256 amount = 1000 ether;
        // we redeem 1000 RA first first
        Asset(ds).approve(address(moduleCore), 1000 ether);
        moduleCore.redeemRaWithDsPa(currencyId, dsId, 1000 ether);

        ff_expired();

        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertTrue(fundsAvailable > 0);

        moduleCore.requestLiquidationFunds(currencyId, fundsAvailable, caller());

        uint256 raBalanceBefore = ra.balanceOf(address(moduleCore));

        ra.approve(address(moduleCore), amount);

        moduleCore.receiveTradeExecuctionResultFunds(currencyId, amount);

        uint256 raBalanceAfter = ra.balanceOf(address(moduleCore));

        vm.assertEq(raBalanceAfter - raBalanceBefore, amount);
    }

    function test_useFundsAfterReceive() external {
        uint256 amount = 1000 ether;

        // we redeem 1000 RA first first
        Asset(ds).approve(address(moduleCore), 1000 ether);
        moduleCore.redeemRaWithDsPa(currencyId, dsId, 1000 ether);

        ff_expired();

        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertTrue(fundsAvailable > 0);

        moduleCore.requestLiquidationFunds(currencyId, fundsAvailable, caller());

        ra.approve(address(moduleCore), amount);

        moduleCore.receiveTradeExecuctionResultFunds(currencyId, amount);

        uint256 tradeFundsAvailable = moduleCore.tradeExecutionFundsAvailable(currencyId);

        vm.assertEq(tradeFundsAvailable, 1010 ether);

        corkConfig.useVaultTradeExecutionResultFunds(currencyId);

        tradeFundsAvailable = moduleCore.tradeExecutionFundsAvailable(currencyId);
        vm.assertEq(tradeFundsAvailable, 0);
    }

    function test_redeemLvShouldPauseDuringLiquidation() external {
        uint256 amount = 10 ether;
        uint256 received = moduleCore.depositLv(currencyId, amount, 0, 0, 0, block.timestamp + 30 minutes);

        Asset(ds).approve(address(moduleCore), 1000 ether);
        moduleCore.redeemRaWithDsPa(currencyId, dsId, 1000 ether);

        ff_expired();

        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);
        vm.assertTrue(fundsAvailable > 0);

        moduleCore.requestLiquidationFunds(currencyId, fundsAvailable, caller());
        Asset lv = Asset(moduleCore.lvAsset(currencyId));
        lv.approve(address(moduleCore), received);

        IVault.RedeemEarlyParams memory redeemParams =
            IVault.RedeemEarlyParams(currencyId, received, 0, block.timestamp, 0, 0, 0);

        vm.expectRevert(IErrors.LVWithdrawalPaused.selector);
        moduleCore.redeemEarlyLv(redeemParams);

        // resume withdrawal when liquidation is finished
        moduleCore.receiveLeftoverFunds(currencyId, received);

        // should work now as withdrawal is resumed
        moduleCore.redeemEarlyLv(redeemParams);
    }
}
