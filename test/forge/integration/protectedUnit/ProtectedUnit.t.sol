// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {ProtectedUnit} from "../../../../contracts/core/assets/ProtectedUnit.sol";
import {Liquidator} from "../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {IErrors} from "../../../../contracts/interfaces/IErrors.sol";
import {DummyERCWithPermit} from "../../../../contracts/dummy/DummyERCWithPermit.sol";
import {Id} from "./../../../../contracts/libraries/Pair.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Asset} from "../../../../contracts/core/assets/Asset.sol";

contract ProtectedUnitTest is Helper {
    Liquidator public liquidator;
    ProtectedUnit public protectedUnit;
    DummyERCWithPermit public dsToken;
    DummyERCWithPermit internal ra;
    DummyERCWithPermit internal pa;

    Id public currencyId;
    uint256 public dsId;

    address public ct;
    address public ds;
    address public owner;
    address public user;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 1900 ether;
    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens
    uint256 constant USER_BALANCE = 500 * 1e18;
    uint256 internal USER_PK = 1;

    // TODO : Add the hookTrampoline address
    address hookTrampoline = DEFAULT_ADDRESS;

    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);
        // Setup accounts
        owner = address(this); // Owner of the contract
        user = vm.rememberKey(USER_PK);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDsWithRaAsPermit(block.timestamp + 1 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000 ether);
        ra.deposit{value: 100000 ether}();
        pa.deposit{value: 100000 ether}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), 100_000_000 ether);

        ra.transfer(user, 1000 ether);

        moduleCore.depositPsm(currencyId, USER_BALANCE * 2);
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0);

        fetchProtocolGeneralInfo();

        // Deploy the Liquidator contract
        liquidator = new Liquidator(address(corkConfig), hookTrampoline, settlementContract, address(moduleCore));

        corkConfig.deployProtectedUnit(currencyId, address(pa), address(ra), "DS/PA", INITIAL_MINT_CAP);
        // Deploy the ProtectedUnit contract
        protectedUnit = ProtectedUnit(protectedUnitFactory.getProtectedUnitAddress(currencyId));

        // Transfer tokens to user for test_ing
        dsToken.transfer(user, USER_BALANCE);
        pa.deposit{value: USER_BALANCE}();
        pa.transfer(user, USER_BALANCE);

        // we disable the redemption fee so its easier to test
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);
    }

    function fetchProtocolGeneralInfo() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (ct, ds) = moduleCore.swapAsset(currencyId, dsId);
        dsToken = DummyERCWithPermit(payable(address(ds)));
    }

    function test_PreviewMint() public {
        // Preview minting 100 ProtectedUnit tokens
        (uint256 dsAmount, uint256 paAmount) = protectedUnit.previewMint(100 * 1e18);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmount, 100 * 1e18);
        assertEq(paAmount, 100 * 1e18);
    }

    function test_PreviewMintRevertWhenMintCapExceeded() public {
        // Preview minting 2000 ProtectedUnit tokens
        vm.expectRevert(IErrors.MintCapExceeded.selector);
        protectedUnit.previewMint(2000 * 1e18);
    }

    function test_MintingTokens() public {
        // Test_ minting by the user
        vm.startPrank(user);

        // Approve tokens for ProtectedUnit contract
        dsToken.approve(address(protectedUnit), USER_BALANCE);
        pa.approve(address(protectedUnit), USER_BALANCE);

        // Mint 100 ProtectedUnit tokens
        uint256 mintAmount = 100 * 1e18;
        protectedUnit.mint(mintAmount);

        // Check balances and total supply
        assertEq(protectedUnit.balanceOf(user), mintAmount);
        assertEq(protectedUnit.totalSupply(), mintAmount);

        // Check token balances in the contract
        assertEq(dsToken.balanceOf(address(protectedUnit)), mintAmount);
        assertEq(pa.balanceOf(address(protectedUnit)), mintAmount);

        vm.stopPrank();
    }

    function test_MintingTokensWithPermit() public {
        // Test_ minting by the user
        vm.startPrank(user);

        // Mint 100 ProtectedUnit tokens
        uint256 mintAmount = 100 * 1e18;

        // Permit token approvals to ProtectedUnit contract
        (uint256 dsAmount, uint256 paAmount) = protectedUnit.previewMint(mintAmount);
        bytes32 domain_separator = Asset(address(dsToken)).DOMAIN_SEPARATOR();
        uint256 deadline = block.timestamp + 10 days;

        bytes memory dsPermit = getCustomPermit(
            user,
            address(protectedUnit),
            dsAmount,
            Asset(address(dsToken)).nonces(user),
            deadline,
            USER_PK,
            domain_separator,
            protectedUnit.DS_PERMIT_MINT_TYPEHASH()
        );

        domain_separator = Asset(address(pa)).DOMAIN_SEPARATOR();

        bytes memory paPermit = getPermit(
            user, address(protectedUnit), paAmount, Asset(address(pa)).nonces(user), deadline, USER_PK, domain_separator
        );

        protectedUnit.mint(user, mintAmount, dsPermit, paPermit, deadline);

        // Check balances and total supply
        assertEq(protectedUnit.balanceOf(user), mintAmount);
        assertEq(protectedUnit.totalSupply(), mintAmount);

        // Check token balances in the contract
        assertEq(dsToken.balanceOf(address(protectedUnit)), mintAmount);
        assertEq(pa.balanceOf(address(protectedUnit)), mintAmount);

        vm.stopPrank();
    }

    function test_MintNotProportional() external {
        // Test_ minting by the user
        vm.startPrank(user);

        uint256 initialAmount = 10 ether;
        // Approve tokens for ProtectedUnit contract
        dsToken.approve(address(protectedUnit), initialAmount);
        pa.approve(address(protectedUnit), initialAmount);

        // Mint 10 ProtectedUnit tokens
        uint256 mintAmount = initialAmount;
        protectedUnit.mint(mintAmount);

        // transfer pa so that the amount is not proportional
        pa.transfer(address(protectedUnit), initialAmount);

        (uint256 dsAmount, uint256 paAmount) = protectedUnit.previewMint(mintAmount);
        vm.assertEq(dsAmount, initialAmount);
        vm.assertEq(paAmount, initialAmount + 10 ether);

        dsToken.approve(address(protectedUnit), dsAmount);
        pa.approve(address(protectedUnit), paAmount);

        uint256 dsBalanceBefore = dsToken.balanceOf(user);
        uint256 paBalanceBefore = pa.balanceOf(user);

        (dsAmount, paAmount) = protectedUnit.mint(initialAmount);

        vm.assertEq(dsToken.balanceOf(user), dsBalanceBefore - dsAmount);
        vm.assertEq(pa.balanceOf(user), paBalanceBefore - paAmount);

        vm.assertEq(dsAmount, initialAmount);
        vm.assertEq(paAmount, initialAmount + 10 ether);
    }

    function test_RedeemRaWithDs() external {
        // Test_ minting by the user
        vm.startPrank(user);

        uint256 initialAmount = 10 ether;
        // Approve tokens for ProtectedUnit contract
        dsToken.approve(address(protectedUnit), initialAmount);
        pa.approve(address(protectedUnit), initialAmount);

        // Mint 10 ProtectedUnit tokens
        uint256 mintAmount = initialAmount;
        protectedUnit.mint(mintAmount);

        vm.stopPrank();
        vm.startPrank(DEFAULT_ADDRESS);

        uint256 paBalnceBefore = pa.balanceOf(address(protectedUnit));
        uint256 dsBalanceBefore = dsToken.balanceOf(address(protectedUnit));
        uint256 raBalanceBefore = ra.balanceOf(address(protectedUnit));

        corkConfig.redeemRaWithDsPaWithProtectedUnit(address(protectedUnit), initialAmount, initialAmount);

        vm.assertEq(pa.balanceOf(address(protectedUnit)), paBalnceBefore - initialAmount);
        vm.assertEq(dsToken.balanceOf(address(protectedUnit)), dsBalanceBefore - initialAmount);
        vm.assertEq(ra.balanceOf(address(protectedUnit)), raBalanceBefore + initialAmount);

        bool paused = protectedUnit.paused();
        vm.assertEq(paused, true);
    }

    function test_MintCapExceeded() public {
        vm.startPrank(user);

        // Approve tokens for ProtectedUnit contract
        dsToken.approve(address(protectedUnit), USER_BALANCE);
        pa.approve(address(protectedUnit), USER_BALANCE);

        // Try minting more than the mint cap
        uint256 mintAmount = 2000 * 1e18; // Exceed the mint cap
        vm.expectRevert(IErrors.MintCapExceeded.selector);
        protectedUnit.mint(mintAmount);

        vm.stopPrank();
    }

    function test_PreviewBurn() public {
        vm.startPrank(user);

        // Mint tokens first
        dsToken.approve(address(protectedUnit), USER_BALANCE);
        pa.approve(address(protectedUnit), USER_BALANCE);
        uint256 mintAmount = 100 * 1e18;
        protectedUnit.mint(mintAmount);

        // Preview dissolving 50 tokens
        (uint256 dsAmount, uint256 paAmount,) = protectedUnit.previewBurn(user, 50 * 1e18);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmount, 50 * 1e18);
        assertEq(paAmount, 50 * 1e18);
        vm.stopPrank();
    }

    function test_PreviewBurnRevertWhenInvalidAmount() public {
        vm.startPrank(user);
        // Preview dissolving more than the user's balance
        vm.expectRevert(IErrors.InvalidAmount.selector);
        protectedUnit.previewBurn(user, 1000 * 1e18);

        dsToken.approve(address(protectedUnit), USER_BALANCE);
        pa.approve(address(protectedUnit), USER_BALANCE);
        uint256 mintAmount = 100 * 1e18;
        protectedUnit.mint(mintAmount);

        vm.expectRevert(IErrors.InvalidAmount.selector);
        protectedUnit.previewBurn(user, 100 * 1e18 + 1);
        vm.stopPrank();
    }

    function test_DissolvingTokens() public {
        // Mint tokens first
        test_MintingTokens();

        vm.startPrank(user);

        uint256 burnAmount = 50 * 1e18;

        // burn 50 tokens
        protectedUnit.burn(burnAmount);

        // Check that the user's ProtectedUnit balance and contract's DS/PA balance decreased
        assertEq(protectedUnit.balanceOf(user), 50 * 1e18); // 100 - 50 = 50 tokens left
        assertEq(dsToken.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50
        assertEq(pa.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50

        vm.stopPrank();
    }

    function test_BurnNotProportional() external {
        vm.startPrank(user);

        uint256 initialAmount = 100 ether;
        // Approve tokens for ProtectedUnit contract
        dsToken.approve(address(protectedUnit), initialAmount);
        pa.approve(address(protectedUnit), initialAmount);

        // Mint 10 ProtectedUnit tokens
        uint256 mintAmount = initialAmount;
        protectedUnit.mint(mintAmount);

        uint256 amount = 10 ether;
        //transfer pa and ra so that the amount is not proportional
        pa.transfer(address(protectedUnit), amount * 10);
        ra.transfer(address(protectedUnit), amount);

        (uint256 dsAmount, uint256 paAmount, uint256 raAmount) = protectedUnit.previewBurn(user, amount);
        vm.assertEq(dsAmount, amount);
        vm.assertEq(paAmount, amount + 10 ether);
        vm.assertEq(raAmount, 1 ether);

        uint256 raBalanceBefore = ra.balanceOf(user);
        uint256 paBalanceBefore = pa.balanceOf(user);
        uint256 dsBalanceBefore = dsToken.balanceOf(user);

        protectedUnit.burn(amount);

        uint256 raBalanceAfter = ra.balanceOf(user);
        uint256 paBalanceAfter = pa.balanceOf(user);
        uint256 dsBalanceAfter = dsToken.balanceOf(user);

        vm.assertEq(raBalanceAfter, raBalanceBefore + raAmount);
        vm.assertEq(paBalanceAfter, paBalanceBefore + paAmount);
        vm.assertEq(dsBalanceAfter, dsBalanceBefore + dsAmount);
    }

    function test_MintingPaused() public {
        // Pause minting
        corkConfig.pauseProtectedUnitMinting(address(protectedUnit));

        // Expect revert when minting while paused
        vm.startPrank(user);
        dsToken.approve(address(protectedUnit), USER_BALANCE);
        pa.approve(address(protectedUnit), USER_BALANCE);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        protectedUnit.mint(100 * 1e18);
        vm.stopPrank();
    }

    function test_MintCapUpdate() public {
        // Update mint cap to a new value
        uint256 newMintCap = 2000 * 1e18;
        corkConfig.updateProtectedUnitMintCap(address(protectedUnit), newMintCap);

        // Check that the mint cap was updated
        assertEq(protectedUnit.mintCap(), newMintCap);
    }

    function test_MintCapUpdateRevert() public {
        // Try to update the mint cap to the same value
        vm.expectRevert(IErrors.InvalidValue.selector);
        corkConfig.updateProtectedUnitMintCap(address(protectedUnit), INITIAL_MINT_CAP);
    }

    function test_deRegister() external {
        address _protectedUnit = protectedUnitFactory.getProtectedUnitAddress(defaultCurrencyId);
        vm.assertTrue(_protectedUnit != address(0));
        corkConfig.deRegisterProtectedUnit(defaultCurrencyId);

        _protectedUnit = protectedUnitFactory.getProtectedUnitAddress(defaultCurrencyId);
        vm.assertTrue(_protectedUnit == address(0));
    }
}
