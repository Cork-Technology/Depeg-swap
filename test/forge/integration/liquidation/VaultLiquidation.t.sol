pragma solidity ^0.8.24;

import "./../../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./../../Helper.sol";
import {DummyWETH} from "./../../../../contracts/dummy/DummyWETH.sol";
import "./../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../../../contracts/libraries/Pair.sol";
import "./../../../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";
import "./../../../../contracts/interfaces/IVault.sol";
import "./../../../../contracts/interfaces/IErrors.sol";
import "./../../../../contracts/interfaces/ILiquidator.sol";
import "./../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";

contract VaultLiquidationTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;

    uint256 public dsId;

    address public ct;
    address public ds;

    Liquidator internal liquidator;

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

        liquidator = new Liquidator(address(corkConfig), address(this), address(moduleCore));

        corkConfig.grantLiquidatorRole(address(liquidator), DEFAULT_ADDRESS);
        corkConfig.whitelist(address(liquidator));

        vm.warp(block.timestamp + 10 days);

        // save initial data
        fetchProtocolGeneralInfo();

        corkConfig.updateAmmTreasurySplitPercentage(defaultCurrencyId, 0);
    }

    function setPreSignature(bytes calldata orderUid, bool signed) external {
        // do nothing, just a place holder
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

        issueNewDs(currencyId);
    }

    function test_liquidationFull() external {
        uint256 amountToSell = 10 ether;

        // we redeem 1000 RA first first
        Asset(ds).approve(address(moduleCore), 1000 ether);
        moduleCore.redeemRaWithDsPa(currencyId, dsId, 1000 ether);

        ff_expired();

        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertTrue(fundsAvailable > amountToSell);

        uint256 tradeFundsAvailable = moduleCore.tradeExecutionFundsAvailable(currencyId);

        // It will be 1% of the total amount because redemption fees are 1%
        vm.assertEq(tradeFundsAvailable, 1000 ether / 100);

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateVaultOrderParams memory params = ILiquidator.CreateVaultOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            vaultId: defaultCurrencyId
        });

        liquidator.createOrderVault(params);

        address receiver = liquidator.fetchVaultReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountToSell);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountToSell);

        liquidator.finishVaultOrder(randomRefId);

        tradeFundsAvailable = moduleCore.tradeExecutionFundsAvailable(currencyId);

        // It will also include redemption fees, so amountToSell + 1000 ether / 100
        vm.assertEq(tradeFundsAvailable, amountToSell + 1000 ether / 100);
    }

    function test_liquidationPartial() external {
        uint256 amountToSell = 10 ether;
        uint256 amountFilled = 4 ether;
        uint256 amountTaken = 4 ether;
        uint256 expectedLeftover = 6 ether;

        // we redeem 1000 RA first first
        Asset(ds).approve(address(moduleCore), 1000 ether);
        moduleCore.redeemRaWithDsPa(currencyId, dsId, 1000 ether);

        ff_expired();

        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertTrue(fundsAvailable > amountToSell);

        uint256 tradeFundsAvailable = moduleCore.tradeExecutionFundsAvailable(currencyId);

        // It will be 1% of the total amount because redemption fees are 1%
        vm.assertEq(tradeFundsAvailable, 1000 ether / 100);

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateVaultOrderParams memory params = ILiquidator.CreateVaultOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            vaultId: defaultCurrencyId
        });

        liquidator.createOrderVault(params);

        address receiver = liquidator.fetchVaultReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountTaken);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountFilled);

        uint256 leftoverBefore = moduleCore.liquidationFundsAvailable(currencyId);

        liquidator.finishVaultOrder(randomRefId);

        tradeFundsAvailable = moduleCore.tradeExecutionFundsAvailable(currencyId);

        // It will also include redemption fees, so amountFilled + 1000 ether / 100
        vm.assertEq(tradeFundsAvailable, amountFilled + 1000 ether / 100);

        uint256 leftoverAfter = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertEq(leftoverAfter, leftoverBefore + expectedLeftover);
    }

    function test_revertIfNotLiquidator() external {
        uint256 amountToSell = 10 ether;

        // we redeem 1000 RA first first
        Asset(ds).approve(address(moduleCore), 1000 ether);
        moduleCore.redeemRaWithDsPa(currencyId, dsId, 1000 ether);

        ff_expired();

        uint256 fundsAvailable = moduleCore.liquidationFundsAvailable(currencyId);

        vm.assertTrue(fundsAvailable > amountToSell);

        uint256 tradeFundsAvailable = moduleCore.tradeExecutionFundsAvailable(currencyId);

        // It will be 1% of the total amount because redemption fees are 1%
        vm.assertEq(tradeFundsAvailable, 1000 ether / 100);

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateVaultOrderParams memory params = ILiquidator.CreateVaultOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            vaultId: defaultCurrencyId
        });
        vm.stopPrank();
        vm.startPrank(address(8));

        vm.expectRevert(IErrors.OnlyLiquidator.selector);
        liquidator.createOrderVault(params);

        vm.expectRevert(IErrors.OnlyLiquidator.selector);
        liquidator.finishVaultOrder(randomRefId);
    }
}
