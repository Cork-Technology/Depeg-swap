// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {HedgeUnit} from "../../../../contracts/core/assets/HedgeUnit.sol";
import {Liquidator} from "../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {IHedgeUnit} from "../../../../contracts/interfaces/IHedgeUnit.sol";
import {DummyWETH} from "../../../../contracts/dummy/DummyWETH.sol";
import {Id} from "./../../../../contracts/libraries/Pair.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";

contract HedgeUnitTest is Helper {
    HedgeUnit public hedgeUnit;
    DummyWETH public dsToken;
    DummyWETH internal ra;
    DummyWETH internal pa;
    Liquidator internal liquidator;

    Id public currencyId;
    uint256 public dsId;

    address public ct;
    address public ds;
    address public owner;
    address public user;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 2050 ether;
    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens
    uint256 constant USER_BALANCE = 500 * 1e18;

    // TODO : Add the hookTrampoline address
    address hookTrampoline = DEFAULT_ADDRESS;

    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Setup accounts
        owner = address(this); // Owner of the contract
        user = address(0x123);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 20 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000 ether);
        ra.deposit{value: 100000 ether}();
        pa.deposit{value: 100000 ether}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), 100_000_000 ether);

        ra.transfer(user, 1000 ether);

        moduleCore.depositPsm(currencyId, USER_BALANCE * 2);
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0);

        fetchProtocolGeneralInfo();

        corkConfig.deployHedgeUnit(currencyId, address(pa), address(ra), "DS/PA", INITIAL_MINT_CAP);
        // Deploy the HedgeUnit contract
        hedgeUnit = HedgeUnit(hedgeUnitFactory.getHedgeUnitAddress(currencyId));

        // Transfer tokens to user for test_ing
        dsToken.transfer(user, USER_BALANCE);
        pa.deposit{value: USER_BALANCE}();
        pa.transfer(user, USER_BALANCE);

        // we disable the redemption fee so its easier to test
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);

        liquidator = new Liquidator(address(corkConfig), DEFAULT_ADDRESS, address(this), address(moduleCore));

        corkConfig.grantLiquidatorRole(address(liquidator), DEFAULT_ADDRESS);
        corkConfig.whitelist(address(liquidator));
        vm.warp(block.timestamp + 10 days);

        uint256 amount = 100 ether;
        pa.approve(address(hedgeUnit), amount);
        dsToken.approve(address(hedgeUnit), amount);

        hedgeUnit.mint(amount);
    }

    function fetchProtocolGeneralInfo() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);
        dsToken = DummyWETH(payable(address(ds)));
    }

    function test_liquidationPartial() external {
        uint256 amountToSell = 10 ether;
        uint256 amountFilled = 4 ether;
        uint256 amountTaken = 4 ether;
        uint256 expectedLeftover = 6 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateHedgeUnitOrderParams memory params = ILiquidator.CreateHedgeUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            hedgeUnit: address(hedgeUnit)
        });

        liquidator.createOrderHedgeUnit(params);

        address receiver = liquidator.fetchHedgeUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountTaken);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountFilled);

        uint256 paBalanceHedgeUnitBefore = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitBefore = ra.balanceOf(address(hedgeUnit));

        liquidator.finishHedgeUnitOrder(randomRefId);

        uint256 paBalanceHedgeUnitAfter = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitAfter = ra.balanceOf(address(hedgeUnit));

        vm.assertEq(paBalanceHedgeUnitAfter - paBalanceHedgeUnitBefore, expectedLeftover);
        vm.assertEq(raBalanceHedgeUnitAfter - raBalanceHedgeUnitBefore, amountFilled);
    }

    function setPreSignature(bytes calldata orderUid, bool signed) external {
        // do nothing, just a place holder
    }

    function test_liquidationFull() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateHedgeUnitOrderParams memory params = ILiquidator.CreateHedgeUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            hedgeUnit: address(hedgeUnit)
        });

        liquidator.createOrderHedgeUnit(params);

        address receiver = liquidator.fetchHedgeUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountToSell);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountToSell);

        uint256 paBalanceHedgeUnitBefore = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitBefore = ra.balanceOf(address(hedgeUnit));

        liquidator.finishHedgeUnitOrder(randomRefId);

        uint256 paBalanceHedgeUnitAfter = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitAfter = ra.balanceOf(address(hedgeUnit));

        vm.assertEq(paBalanceHedgeUnitAfter - paBalanceHedgeUnitBefore, 0);
        vm.assertEq(raBalanceHedgeUnitAfter - raBalanceHedgeUnitBefore, amountToSell);
    }

    function test_liquidationAndExecuteTrade() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateHedgeUnitOrderParams memory params = ILiquidator.CreateHedgeUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            hedgeUnit: address(hedgeUnit)
        });

        liquidator.createOrderHedgeUnit(params);

        address receiver = liquidator.fetchHedgeUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountToSell);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountToSell);

        uint256 paBalanceHedgeUnitBefore = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitBefore = ra.balanceOf(address(hedgeUnit));
        uint256 dsBalanceHedgeUnitBefore = dsToken.balanceOf(address(hedgeUnit));

        uint256 dsBought = liquidator.finishHedgeUnitOrderAndExecuteTrade(randomRefId, 0, defaultBuyApproxParams());

        uint256 paBalanceHedgeUnitAfter = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitAfter = ra.balanceOf(address(hedgeUnit));
        uint256 dsBalanceHedgeUnitAfter = dsToken.balanceOf(address(hedgeUnit));

        vm.assertEq(paBalanceHedgeUnitAfter - paBalanceHedgeUnitBefore, 0);
        vm.assertEq(raBalanceHedgeUnitAfter - raBalanceHedgeUnitBefore, 0);
        vm.assertEq(dsBalanceHedgeUnitAfter - dsBalanceHedgeUnitBefore, dsBought);
    }

    function test_liquidationAndExecuteTradeWhenItReverts() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateHedgeUnitOrderParams memory params = ILiquidator.CreateHedgeUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            hedgeUnit: address(hedgeUnit)
        });

        liquidator.createOrderHedgeUnit(params);

        address receiver = liquidator.fetchHedgeUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountToSell);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountToSell);

        uint256 paBalanceHedgeUnitBefore = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitBefore = ra.balanceOf(address(hedgeUnit));
        uint256 dsBalanceHedgeUnitBefore = dsToken.balanceOf(address(hedgeUnit));

        uint256 dsBought =
            liquidator.finishHedgeUnitOrderAndExecuteTrade(randomRefId, 10000000 ether, defaultBuyApproxParams());
        vm.assertEq(dsBought, 0);

        uint256 paBalanceHedgeUnitAfter = pa.balanceOf(address(hedgeUnit));
        uint256 raBalanceHedgeUnitAfter = ra.balanceOf(address(hedgeUnit));
        uint256 dsBalanceHedgeUnitAfter = dsToken.balanceOf(address(hedgeUnit));

        vm.assertEq(paBalanceHedgeUnitAfter - paBalanceHedgeUnitBefore, 0);
        vm.assertEq(raBalanceHedgeUnitAfter - raBalanceHedgeUnitBefore, amountToSell);
        vm.assertEq(dsBalanceHedgeUnitAfter - dsBalanceHedgeUnitBefore, 0);
    }

    function test_revertIfNotLiquidator() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateHedgeUnitOrderParams memory params = ILiquidator.CreateHedgeUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            hedgeUnit: address(hedgeUnit)
        });

        vm.startPrank(address(99));
        vm.expectRevert();
        liquidator.createOrderHedgeUnit(params);

        vm.expectRevert();
        liquidator.finishHedgeUnitOrderAndExecuteTrade(randomRefId, 10000000 ether, defaultBuyApproxParams());
    }
}
