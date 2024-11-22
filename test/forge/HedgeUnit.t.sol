// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./Helper.sol";
import {HedgeUnit} from "../../contracts/core/assets/HedgeUnit.sol";
import {Liquidator} from "../../contracts/core/liquidators/Liquidator.sol";
import {IHedgeUnit} from "../../contracts/interfaces/IHedgeUnit.sol";
import {DummyWETH} from "../../contracts/dummy/DummyWETH.sol";
import {Id} from "./../../contracts/libraries/Pair.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract HedgeUnitTest is Helper {
    Liquidator public liquidator;
    HedgeUnit public hedgeUnit;
    DummyWETH public dsToken;
    DummyWETH internal ra;
    DummyWETH internal pa;

    Id public currencyId;
    uint256 public dsId;

    address public ct;
    address public ds;
    address public owner;
    address public user;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 1900 ether;
    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens
    uint256 constant USER_BALANCE = 500 * 1e18;

    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Setup accounts
        owner = address(this); // Owner of the contract
        user = address(0x123);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 1 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000 ether);
        ra.deposit{value: 100000 ether}();
        pa.deposit{value: 100000 ether}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), 100_000_000 ether);

        moduleCore.depositPsm(currencyId, USER_BALANCE * 2);
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0);

        fetchProtocolGeneralInfo();

        // Deploy the Liquidator contract
        liquidator = new Liquidator(DEFAULT_ADDRESS, 10000, settlementContract);

        // Deploy the HedgeUnit contract
        hedgeUnit = new HedgeUnit(
            address(moduleCore),
            address(liquidator),
            currencyId,
            address(pa),
            "DS/PA",
            INITIAL_MINT_CAP,
            DEFAULT_ADDRESS
        );
        liquidator.updateLiquidatorRole(address(hedgeUnit), true);

        // Transfer tokens to user for testing
        dsToken.transfer(user, USER_BALANCE);
        pa.deposit{value: USER_BALANCE}();
        pa.transfer(user, USER_BALANCE);
    }

    function fetchProtocolGeneralInfo() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);
        dsToken = DummyWETH(payable(address(ds)));
    }

    function testPreviewMint() public {
        // Preview minting 100 HedgeUnit tokens
        (uint256 dsAmount, uint256 paAmount) = hedgeUnit.previewMint(100 * 1e18);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmount, 100 * 1e18);
        assertEq(paAmount, 100 * 1e18);
    }

    function testPreviewMintRevertWhenMintCapExceeded() public {
        // Preview minting 2000 HedgeUnit tokens
        vm.expectRevert(IHedgeUnit.MintCapExceeded.selector);
        hedgeUnit.previewMint(2000 * 1e18);
    }

    function testMintingTokens() public {
        // Test minting by the user
        vm.startPrank(user);

        // Approve tokens for HedgeUnit contract
        dsToken.approve(address(hedgeUnit), USER_BALANCE);
        pa.approve(address(hedgeUnit), USER_BALANCE);

        // Mint 100 HedgeUnit tokens
        uint256 mintAmount = 100 * 1e18;
        hedgeUnit.mint(mintAmount);

        // Check balances and total supply
        assertEq(hedgeUnit.balanceOf(user), mintAmount);
        assertEq(hedgeUnit.totalSupply(), mintAmount);

        // Check token balances in the contract
        assertEq(dsToken.balanceOf(address(hedgeUnit)), mintAmount);
        assertEq(pa.balanceOf(address(hedgeUnit)), mintAmount);

        vm.stopPrank();
    }

    function testMintCapExceeded() public {
        vm.startPrank(user);

        // Approve tokens for HedgeUnit contract
        dsToken.approve(address(hedgeUnit), USER_BALANCE);
        pa.approve(address(hedgeUnit), USER_BALANCE);

        // Try minting more than the mint cap
        uint256 mintAmount = 2000 * 1e18; // Exceed the mint cap
        vm.expectRevert(IHedgeUnit.MintCapExceeded.selector);
        hedgeUnit.mint(mintAmount);

        vm.stopPrank();
    }

    function testPreviewDissolve() public {
        // Mint tokens first
        dsToken.approve(address(hedgeUnit), USER_BALANCE);
        pa.approve(address(hedgeUnit), USER_BALANCE);
        uint256 mintAmount = 100 * 1e18;
        hedgeUnit.mint(mintAmount);

        // Preview dissolving 50 tokens
        (uint256 dsAmount, uint256 paAmount) = hedgeUnit.previewDissolve(50 * 1e18);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmount, 50 * 1e18);
        assertEq(paAmount, 50 * 1e18);
    }

    function testPreviewDissolveRevertWhenInvalidAmount() public {
        // Preview dissolving more than the user's balance
        vm.expectRevert(IHedgeUnit.InvalidAmount.selector);
        hedgeUnit.previewDissolve(1000 * 1e18);

        dsToken.approve(address(hedgeUnit), USER_BALANCE);
        pa.approve(address(hedgeUnit), USER_BALANCE);
        uint256 mintAmount = 100 * 1e18;
        hedgeUnit.mint(mintAmount);

        vm.expectRevert(IHedgeUnit.InvalidAmount.selector);
        hedgeUnit.previewDissolve(100 * 1e18 + 1);
    }

    function testDissolvingTokens() public {
        // Mint tokens first
        testMintingTokens();

        vm.startPrank(user);

        uint256 dissolveAmount = 50 * 1e18;

        // Dissolve 50 tokens
        hedgeUnit.dissolve(dissolveAmount);

        // Check that the user's HedgeUnit balance and contract's DS/PA balance decreased
        assertEq(hedgeUnit.balanceOf(user), 50 * 1e18); // 100 - 50 = 50 tokens left
        assertEq(dsToken.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50
        assertEq(pa.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50

        vm.stopPrank();
    }

    function testMintingPaused() public {
        // Pause minting
        hedgeUnit.pause();

        // Expect revert when minting while paused
        vm.startPrank(user);
        dsToken.approve(address(hedgeUnit), USER_BALANCE);
        pa.approve(address(hedgeUnit), USER_BALANCE);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        hedgeUnit.mint(100 * 1e18);
        vm.stopPrank();
    }

    function testMintCapUpdate() public {
        // Update mint cap to a new value
        uint256 newMintCap = 2000 * 1e18;
        hedgeUnit.updateMintCap(newMintCap);

        // Check that the mint cap was updated
        assertEq(hedgeUnit.mintCap(), newMintCap);
    }

    function testMintCapUpdateRevert() public {
        // Try to update the mint cap to the same value
        vm.expectRevert(IHedgeUnit.InvalidValue.selector);
        hedgeUnit.updateMintCap(INITIAL_MINT_CAP);
    }
}
