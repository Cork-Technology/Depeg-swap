// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {ProtectedUnit} from "../../../../contracts/core/assets/ProtectedUnit.sol";
import {Liquidator} from "../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {IProtectedUnit} from "../../../../contracts/interfaces/IProtectedUnit.sol";
import {DummyWETH} from "../../../../contracts/dummy/DummyWETH.sol";
import {Id} from "./../../../../contracts/libraries/Pair.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

contract ProtectedUnitTest is Helper {
    ProtectedUnit public protectedUnit;
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
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0, 0);

        fetchProtocolGeneralInfo();

        corkConfig.deployProtectedUnit(currencyId, address(pa), address(ra), "DS/PA", INITIAL_MINT_CAP);
        // Deploy the ProtectedUnit contract
        protectedUnit = ProtectedUnit(protectedUnitFactory.getProtectedUnitAddress(currencyId));

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
        pa.approve(permit2, amount);
        dsToken.approve(permit2, amount);

        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(amount), uint48(block.timestamp + 10 days)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(amount), uint48(block.timestamp + 10 days)
        );
        protectedUnit.mint(amount);
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

        ILiquidator.CreateProtectedUnitOrderParams memory params = ILiquidator.CreateProtectedUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            protectedUnit: address(protectedUnit)
        });

        liquidator.createOrderProtectedUnit(params);

        address receiver = liquidator.fetchProtectedUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountTaken);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountFilled);

        uint256 paBalanceProtectedUnitBefore = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitBefore = ra.balanceOf(address(protectedUnit));

        liquidator.finishProtectedUnitOrder(randomRefId);

        uint256 paBalanceProtectedUnitAfter = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitAfter = ra.balanceOf(address(protectedUnit));

        vm.assertEq(paBalanceProtectedUnitAfter - paBalanceProtectedUnitBefore, expectedLeftover);
        vm.assertEq(raBalanceProtectedUnitAfter - raBalanceProtectedUnitBefore, amountFilled);
    }

    function setPreSignature(bytes calldata orderUid, bool signed) external {
        // do nothing, just a place holder
    }

    function test_liquidationFull() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateProtectedUnitOrderParams memory params = ILiquidator.CreateProtectedUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            protectedUnit: address(protectedUnit)
        });

        liquidator.createOrderProtectedUnit(params);

        address receiver = liquidator.fetchProtectedUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountToSell);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountToSell);

        uint256 paBalanceProtectedUnitBefore = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitBefore = ra.balanceOf(address(protectedUnit));

        liquidator.finishProtectedUnitOrder(randomRefId);

        uint256 paBalanceProtectedUnitAfter = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitAfter = ra.balanceOf(address(protectedUnit));

        vm.assertEq(paBalanceProtectedUnitAfter - paBalanceProtectedUnitBefore, 0);
        vm.assertEq(raBalanceProtectedUnitAfter - raBalanceProtectedUnitBefore, amountToSell);
    }

    function test_liquidationAndExecuteTrade() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateProtectedUnitOrderParams memory params = ILiquidator.CreateProtectedUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            protectedUnit: address(protectedUnit)
        });

        liquidator.createOrderProtectedUnit(params);

        address receiver = liquidator.fetchProtectedUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountToSell);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountToSell);

        uint256 paBalanceProtectedUnitBefore = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitBefore = ra.balanceOf(address(protectedUnit));
        uint256 dsBalanceProtectedUnitBefore = dsToken.balanceOf(address(protectedUnit));

        uint256 dsBought = liquidator.finishProtectedUnitOrderAndExecuteTrade(
            randomRefId, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        uint256 paBalanceProtectedUnitAfter = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitAfter = ra.balanceOf(address(protectedUnit));
        uint256 dsBalanceProtectedUnitAfter = dsToken.balanceOf(address(protectedUnit));

        vm.assertEq(paBalanceProtectedUnitAfter - paBalanceProtectedUnitBefore, 0);
        vm.assertEq(raBalanceProtectedUnitAfter - raBalanceProtectedUnitBefore, 0);
        vm.assertEq(dsBalanceProtectedUnitAfter - dsBalanceProtectedUnitBefore, dsBought);
    }

    function test_liquidationAndExecuteTradeWhenItReverts() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateProtectedUnitOrderParams memory params = ILiquidator.CreateProtectedUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            protectedUnit: address(protectedUnit)
        });

        liquidator.createOrderProtectedUnit(params);

        address receiver = liquidator.fetchProtectedUnitReceiver(randomRefId);

        // mimic trade execution
        vm.stopPrank();
        pa.transferFrom(address(receiver), address(this), amountToSell);

        vm.startPrank(DEFAULT_ADDRESS);
        ra.transfer(address(receiver), amountToSell);

        uint256 paBalanceProtectedUnitBefore = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitBefore = ra.balanceOf(address(protectedUnit));
        uint256 dsBalanceProtectedUnitBefore = dsToken.balanceOf(address(protectedUnit));

        uint256 dsBought = liquidator.finishProtectedUnitOrderAndExecuteTrade(
            randomRefId, 10000000 ether, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        vm.assertEq(dsBought, 0);

        uint256 paBalanceProtectedUnitAfter = pa.balanceOf(address(protectedUnit));
        uint256 raBalanceProtectedUnitAfter = ra.balanceOf(address(protectedUnit));
        uint256 dsBalanceProtectedUnitAfter = dsToken.balanceOf(address(protectedUnit));

        vm.assertEq(paBalanceProtectedUnitAfter - paBalanceProtectedUnitBefore, 0);
        vm.assertEq(raBalanceProtectedUnitAfter - raBalanceProtectedUnitBefore, amountToSell);
        vm.assertEq(dsBalanceProtectedUnitAfter - dsBalanceProtectedUnitBefore, 0);
    }

    function test_revertIfNotLiquidator() external {
        uint256 amountToSell = 10 ether;

        bytes32 randomRefId = keccak256("ref");
        // irrelevant, since we're testing the logic ourself
        bytes memory randomOrderUid = bytes.concat(keccak256("orderUid"));

        ILiquidator.CreateProtectedUnitOrderParams memory params = ILiquidator.CreateProtectedUnitOrderParams({
            internalRefId: randomRefId,
            orderUid: randomOrderUid,
            sellToken: address(pa),
            sellAmount: amountToSell,
            buyToken: address(ra),
            protectedUnit: address(protectedUnit)
        });

        vm.startPrank(address(99));
        vm.expectRevert();
        liquidator.createOrderProtectedUnit(params);

        vm.expectRevert();
        liquidator.finishProtectedUnitOrderAndExecuteTrade(
            randomRefId, 10000000 ether, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
    }
}
