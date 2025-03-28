// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {ProtectedUnit} from "../../../../contracts/core/assets/ProtectedUnit.sol";
import {Liquidator} from "../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {IProtectedUnit} from "../../../../contracts/interfaces/IProtectedUnit.sol";
import {DummyWETH} from "../../../../contracts/dummy/DummyWETH.sol";
import {Id} from "./../../../../contracts/libraries/Pair.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

contract ProtectedUnitTest is Helper {
    ProtectedUnit public protectedUnit;
    DummyWETH public dsToken;
    DummyWETH internal ra;
    DummyWETH internal pa;

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

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 10 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000 ether);
        ra.deposit{value: 100000 ether}();
        pa.deposit{value: 100000 ether}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), 100_000_000 ether);

        ra.transfer(user, 1000 ether);

        moduleCore.depositPsm(currencyId, USER_BALANCE * 2);
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0, 0);

        fetchProtocolGeneralInfo();

        // register self as liquidator
        corkConfig.whitelist(DEFAULT_ADDRESS);
        vm.warp(7 days + 1);

        corkConfig.deployProtectedUnit(currencyId, address(pa), address(ra), "DS/PA", INITIAL_MINT_CAP);
        // Deploy the ProtectedUnit contract
        protectedUnit = ProtectedUnit(protectedUnitFactory.getProtectedUnitAddress(currencyId));

        // Transfer tokens to user for test_ing
        dsToken.transfer(user, USER_BALANCE);
        pa.deposit{value: USER_BALANCE}();
        pa.transfer(user, USER_BALANCE);

        // we disable the redemption fee so its easier to test
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);

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

    function test_requestFunds() external {
        uint256 requestAmount = 10 ether;

        uint256 balancePaBefore = pa.balanceOf(DEFAULT_ADDRESS);

        protectedUnit.requestLiquidationFunds(requestAmount, address(pa));

        uint256 balancePaAfter = pa.balanceOf(DEFAULT_ADDRESS);

        assertEq(balancePaAfter - balancePaBefore, requestAmount);
    }

    function test_receiveFunds() external {
        uint256 requestAmount = 10 ether;

        pa.approve(address(protectedUnit), requestAmount);

        uint256 balancePaBefore = pa.balanceOf(address(protectedUnit));

        protectedUnit.receiveFunds(requestAmount, address(pa));

        uint256 balancePaAfter = pa.balanceOf(address(protectedUnit));

        assertEq(balancePaAfter - balancePaBefore, requestAmount);
    }

    function test_useFunds() external {
        uint256 requestAmount = 10 ether;

        ra.approve(address(protectedUnit), requestAmount);

        uint256 balancePaBefore = pa.balanceOf(address(protectedUnit));

        protectedUnit.receiveFunds(requestAmount, address(ra));

        uint256 dsBalanceBefore = dsToken.balanceOf(address(protectedUnit));
        uint256 amountOut = corkConfig.buyDsFromProtectedUnit(
            address(protectedUnit), requestAmount, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );

        uint256 dsBalanceAfter = dsToken.balanceOf(address(protectedUnit));

        assertEq(dsBalanceAfter - dsBalanceBefore, amountOut);
    }

    function test_fundsAvailable() external {
        uint256 requestAmount = 10 ether;

        pa.approve(address(protectedUnit), requestAmount);

        uint256 fundsAvailableBefore = protectedUnit.fundsAvailable(address(pa));

        protectedUnit.receiveFunds(requestAmount, address(pa));

        uint256 fundsAvailableAfter = protectedUnit.fundsAvailable(address(pa));

        vm.assertEq(fundsAvailableAfter - fundsAvailableBefore, requestAmount);
    }
}
