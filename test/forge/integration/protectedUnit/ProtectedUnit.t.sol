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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SigUtils} from "../../SigUtils.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

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
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0, 0, block.timestamp);

        fetchProtocolGeneralInfo();

        // Deploy the Liquidator contract
        liquidator = new Liquidator(address(corkConfig), settlementContract, address(moduleCore));

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
        assertEq(protectedUnit.balanceOf(user), 0);
        assertEq(protectedUnit.totalSupply(), 0);
        assertEq(dsToken.balanceOf(address(protectedUnit)), 0);
        assertEq(pa.balanceOf(address(protectedUnit)), 0);

        uint256 dsBalanceBefore = dsToken.balanceOf(user);
        uint256 paBalanceBefore = pa.balanceOf(user);

        pa.approve(permit2, USER_BALANCE);
        dsToken.approve(permit2, USER_BALANCE);

        // Approve tokens for ProtectedUnit contract
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );

        // Mint 100 ProtectedUnit tokens
        uint256 mintAmount = 100 * 1e18;
        protectedUnit.mint(mintAmount);

        // Check balances and total supply
        assertEq(protectedUnit.balanceOf(user), mintAmount);
        assertEq(protectedUnit.totalSupply(), mintAmount);

        // Check token balances in the contract
        assertEq(dsToken.balanceOf(address(protectedUnit)), mintAmount);
        assertEq(pa.balanceOf(address(protectedUnit)), mintAmount);

        // Check user token balances decreased correctly
        assertEq(dsToken.balanceOf(user), dsBalanceBefore - mintAmount);
        assertEq(pa.balanceOf(user), paBalanceBefore - mintAmount);

        (address dsAddress, uint256 totalDeposited) =
            protectedUnit.dsHistory(protectedUnit.dsIndexMap(address(dsToken)));
        assertEq(dsAddress, address(dsToken));
        assertEq(totalDeposited, mintAmount);

        vm.stopPrank();
    }

    function test_MintingTokensWithPermit() public {
        // Test minting by the user
        vm.startPrank(user);

        // Approve tokens for Permit2
        dsToken.approve(address(permit2), USER_BALANCE);
        pa.approve(address(permit2), USER_BALANCE);

        // Mint 100 ProtectedUnit tokens
        uint256 mintAmount = 100 * 1e18;

        // Calculate token amounts needed for minting
        (uint256 dsAmount, uint256 paAmount) = protectedUnit.previewMint(mintAmount);

        // Create the tokens array
        address[] memory tokens = new address[](2);
        tokens[0] = address(dsToken);
        tokens[1] = address(pa);

        IAllowanceTransfer.PermitBatch memory permitBatchData;
        {
            // Set up nonce and deadline
            uint48 nonce = uint48(0);
            uint48 deadline = uint48(block.timestamp + 1 hours);

            // Create the Permit2 PermitBatchTransferFrom struct
            IAllowanceTransfer.PermitDetails[] memory permitted = new IAllowanceTransfer.PermitDetails[](2);
            permitted[0] = IAllowanceTransfer.PermitDetails({
                token: address(dsToken),
                amount: uint160(dsAmount),
                expiration: deadline,
                nonce: nonce
            });
            permitted[1] = IAllowanceTransfer.PermitDetails({
                token: address(pa),
                amount: uint160(paAmount),
                expiration: deadline,
                nonce: nonce
            });

            permitBatchData = IAllowanceTransfer.PermitBatch({
                details: permitted,
                spender: address(protectedUnit),
                sigDeadline: deadline
            });
        }
        // Generate the batch permit signature
        bytes memory signature = getPermitBatchSignature(permitBatchData, USER_PK, IPermit2(permit2).DOMAIN_SEPARATOR());

        // Record initial balances
        uint256 startBalanceDS = dsToken.balanceOf(user);
        uint256 startBalancePA = pa.balanceOf(user);
        uint256 startBalancePU = protectedUnit.balanceOf(user);

        assertEq(startBalancePU, 0);
        assertEq(protectedUnit.totalSupply(), 0);
        assertEq(dsToken.balanceOf(address(protectedUnit)), 0);
        assertEq(pa.balanceOf(address(protectedUnit)), 0);

        // Call the mint function with Permit2 data
        (uint256 actualDsAmount, uint256 actualPaAmount) = protectedUnit.mint(mintAmount, permitBatchData, signature);

        // Check amounts returned
        assertEq(actualDsAmount, dsAmount);
        assertEq(actualPaAmount, paAmount);

        // Check balances and total supply
        assertEq(protectedUnit.balanceOf(user), startBalancePU + mintAmount);
        assertEq(protectedUnit.totalSupply(), mintAmount);

        // Check user token balances decreased correctly
        assertEq(dsToken.balanceOf(user), startBalanceDS - dsAmount);
        assertEq(pa.balanceOf(user), startBalancePA - paAmount);

        // Check token balances in the contract
        assertEq(dsToken.balanceOf(address(protectedUnit)), dsAmount);
        assertEq(pa.balanceOf(address(protectedUnit)), paAmount);

        (address dsAddress, uint256 totalDeposited) =
            protectedUnit.dsHistory(protectedUnit.dsIndexMap(address(dsToken)));
        assertEq(dsAddress, address(dsToken));
        assertEq(totalDeposited, mintAmount);
        vm.stopPrank();
    }

    function test_mint_safe_against_dos() public {
        address user = address(0x123);
        address frontrunner = address(0x456);

        // Give user1 some RA tokens to test with
        vm.deal(user, 100000000000 ether);
        vm.deal(frontrunner, 100000000000 ether);

        vm.startPrank(user);
        ra.deposit{value: 1000000000 ether}();
        pa.deposit{value: 1000000000 ether}();
        vm.stopPrank();

        vm.startPrank(frontrunner);
        ra.deposit{value: 1000000000 ether}();
        pa.deposit{value: 1000000000 ether}();
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(ra).transfer(address(manager), 1e18);

        ra.approve(address(moduleCore), 20000e18);
        moduleCore.depositPsm(currencyId, 20000e18);

        ra.approve(address(moduleCore), 20000e18);
        moduleCore.depositLv(currencyId, 2000e18, 0, 0, 0, block.timestamp);

        (address ct, address ds) = moduleCore.swapAsset(currencyId, moduleCore.lastDsId(currencyId));
        ProtectedUnit pu = ProtectedUnit(protectedUnitFactory.getProtectedUnitAddress(currencyId));

        deal(ds, user, 100e18);
        deal(ds, frontrunner, 1000e18);

        vm.startPrank(user);
        uint256 dsBalanceBefore = IERC20(ds).balanceOf(user);
        uint256 paBalanceBefore = pa.balanceOf(user);

        (uint256 requiredDsAmt, uint256 requiredPUAmt) = pu.previewMint(1e18);
        pa.approve(permit2, type(uint256).max);
        dsToken.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(address(pa), address(pu), uint160(requiredPUAmt), uint48(block.timestamp + 1 hours));
        IPermit2(permit2).approve(address(dsToken), address(pu), uint160(1e18), uint48(block.timestamp + 1 hours));

        (uint256 dsAmount, uint256 paAmount) = pu.mint(1e18);

        vm.assertEq(IERC20(ds).balanceOf(user), dsBalanceBefore - requiredDsAmt);
        vm.assertEq(pa.balanceOf(user), paBalanceBefore - requiredPUAmt);

        vm.startPrank(user);
        (requiredDsAmt, requiredPUAmt) = pu.previewMint(99e18);
        IPermit2(permit2).approve(address(pa), address(pu), uint160(requiredPUAmt), uint48(block.timestamp + 1 hours));
        IPermit2(permit2).approve(
            address(dsToken), address(pu), uint160(requiredDsAmt), uint48(block.timestamp + 1 hours)
        );

        // frontrunner directly transfers 100 ether to the protected unit
        vm.startPrank(frontrunner);
        pa.transfer(address(pu), 100 ether);

        vm.startPrank(user);
        (dsAmount, paAmount) = pu.mint(99e18);
        vm.stopPrank();
    }

    function test_MintNotProportional() external {
        // Test_ minting by the user
        vm.startPrank(user);
        pa.approve(permit2, type(uint256).max);
        dsToken.approve(permit2, type(uint256).max);

        uint256 initialAmount = 10 ether;
        // Approve tokens for ProtectedUnit contract
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(initialAmount), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(initialAmount), uint48(block.timestamp + 1 hours)
        );

        // Mint 10 ProtectedUnit tokens
        uint256 mintAmount = initialAmount;
        protectedUnit.mint(mintAmount);

        // transfer pa so that the amount is not proportional
        pa.transfer(address(protectedUnit), initialAmount);

        (uint256 dsAmount, uint256 paAmount) = protectedUnit.previewMint(mintAmount);
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(paAmount), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(dsAmount), uint48(block.timestamp + 1 hours)
        );

        uint256 dsBalanceBefore = dsToken.balanceOf(user);
        uint256 paBalanceBefore = pa.balanceOf(user);

        (dsAmount, paAmount) = protectedUnit.mint(initialAmount);

        vm.assertEq(dsToken.balanceOf(user), dsBalanceBefore - dsAmount);
        vm.assertEq(pa.balanceOf(user), paBalanceBefore - paAmount);
        vm.stopPrank();
    }

    function test_RedeemRaWithDs() external {
        // Test_ minting by the user
        vm.startPrank(user);

        uint256 initialAmount = 10 ether;
        // Approve tokens for ProtectedUnit contract
        pa.approve(permit2, type(uint256).max);
        dsToken.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(initialAmount), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(initialAmount), uint48(block.timestamp + 1 hours)
        );

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

        vm.stopPrank();
    }

    function test_MintCapExceeded() public {
        vm.startPrank(user);

        // Approve tokens for ProtectedUnit contract
        pa.approve(permit2, type(uint256).max);
        dsToken.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );

        // Try minting more than the mint cap
        uint256 mintAmount = 2000 * 1e18; // Exceed the mint cap
        vm.expectRevert(IErrors.MintCapExceeded.selector);
        protectedUnit.mint(mintAmount);

        vm.stopPrank();
    }

    function test_PreviewBurn() public {
        vm.startPrank(user);

        // Mint tokens first
        pa.approve(permit2, type(uint256).max);
        dsToken.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );

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

        pa.approve(permit2, type(uint256).max);
        dsToken.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );

        uint256 mintAmount = 100 * 1e18;
        protectedUnit.mint(mintAmount);

        vm.expectRevert(IErrors.InvalidAmount.selector);
        protectedUnit.previewBurn(user, 100 * 1e18 + 1);
        vm.stopPrank();
    }

    function test_BurnPU() public {
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
        pa.approve(permit2, type(uint256).max);
        dsToken.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(initialAmount), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(initialAmount), uint48(block.timestamp + 1 hours)
        );

        // Mint 10 ProtectedUnit tokens
        uint256 mintAmount = initialAmount;
        protectedUnit.mint(mintAmount);

        uint256 amount = 10 ether;
        //transfer pa and ra so that the amount is not proportional
        pa.transfer(address(protectedUnit), amount * 10);
        ra.transfer(address(protectedUnit), amount);

        (uint256 dsAmount, uint256 paAmount, uint256 raAmount) = protectedUnit.previewBurn(user, amount);

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

        vm.stopPrank();
    }

    function test_DsReserveShouldSetToZeroAfterDsExpiry() public {
        vm.assertEq(protectedUnit.dsReserve(), 0);

        vm.startPrank(user);
        pa.approve(permit2, USER_BALANCE);
        dsToken.approve(permit2, USER_BALANCE);

        // Approve tokens for ProtectedUnit contract
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 4 days)
        );
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 4 days)
        );

        // Mint 100 ProtectedUnit tokens
        uint256 mintAmount = 100 * 1e18;
        protectedUnit.mint(mintAmount);
        vm.assertEq(protectedUnit.dsReserve(), mintAmount);

        vm.startPrank(DEFAULT_ADDRESS);
        // Advance time to expire the DS
        vm.warp(block.timestamp + 2 days);

        // issue new DS
        issueNewDs(currencyId);
        fetchProtocolGeneralInfo();
        moduleCore.depositPsm(currencyId, USER_BALANCE * 2);

        // Transfer tokens to user for test_ing
        dsToken.transfer(user, USER_BALANCE);

        vm.startPrank(user);
        // Approve New DS token for ProtectedUnit contract
        dsToken.approve(permit2, USER_BALANCE);
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 4 days)
        );
        // mint again the ProtectedUnit so here it will use the new DS instead of the expired DS
        protectedUnit.mint(10);

        // DS reserve should be 0 because the DS has expired and expired DS value is 0 so it will not be counted
        vm.assertEq(protectedUnit.dsReserve(), 0);

        (address dsAddress, uint256 totalDeposited) =
            protectedUnit.dsHistory(protectedUnit.dsIndexMap(address(dsToken)));
        assertEq(dsAddress, address(dsToken));
        assertEq(totalDeposited, 0);
        vm.stopPrank();
    }

    function test_MintingPaused() public {
        // Pause minting
        corkConfig.pauseProtectedUnitMinting(address(protectedUnit));

        // Expect revert when minting while paused
        vm.startPrank(user);
        dsToken.approve(permit2, type(uint256).max);
        pa.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );
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
