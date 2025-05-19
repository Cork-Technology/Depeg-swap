// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {ProtectedUnit} from "../../../../contracts/core/assets/ProtectedUnit.sol";
import {Liquidator} from "../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {DummyERCWithPermit} from "../../../../contracts/dummy/DummyERCWithPermit.sol";
import {Id} from "../../../../contracts/libraries/Pair.sol";
import {IProtectedUnitRouter} from "../../../../contracts/interfaces/IProtectedUnitRouter.sol";
import {Asset} from "../../../../contracts/core/assets/Asset.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

contract ProtectedUnitRouterTest is Helper {
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
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0, 0, block.timestamp);

        fetchProtocolGeneralInfo();

        // Deploy the Liquidator contract
        liquidator = new Liquidator(address(corkConfig), hookTrampoline, settlementContract, address(moduleCore));

        // Deploy the ProtectedUnit contract
        corkConfig.deployProtectedUnit(currencyId, address(pa), address(ra), "DS/PA", INITIAL_MINT_CAP);
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
        address[] memory protectedUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        protectedUnits[0] = address(protectedUnit);
        amounts[0] = 100 * 1e18;

        uint256[] memory dsAmounts = new uint256[](1);
        uint256[] memory paAmounts = new uint256[](1);

        // Preview minting 100 ProtectedUnit tokens
        (dsAmounts, paAmounts) = protectedUnitRouter.previewBatchMint(protectedUnits, amounts);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmounts[0], 100 * 1e18);
        assertEq(paAmounts[0], 100 * 1e18);
    }

    function mintTokens() public {
        // Test_ minting by the user
        vm.startPrank(user);

        // Approve tokens for ProtectedUnit contract
        dsToken.approve(permit2, type(uint256).max);
        pa.approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(
            address(dsToken), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
        );
        IPermit2(permit2).approve(
            address(pa), address(protectedUnit), uint160(USER_BALANCE), uint48(block.timestamp + 1 hours)
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

        vm.stopPrank();
    }

    function test_BatchMint() public {
        // Test minting by the user
        vm.startPrank(user);

        // Approve tokens for Permit2
        dsToken.approve(permit2, type(uint256).max);
        pa.approve(permit2, type(uint256).max);

        // Mint 100 ProtectedUnit tokens
        uint256 mintAmount = 100 * 1e18;

        // Setup the Protected Units array with just one unit for this test
        address[] memory protectedUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        protectedUnits[0] = address(protectedUnit);
        amounts[0] = mintAmount;

        // Calculate token amounts needed for minting
        (uint256[] memory dsAmounts, uint256[] memory paAmounts) =
            protectedUnitRouter.previewBatchMint(protectedUnits, amounts);

        // Set up nonce and deadline
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 10 minutes;

        ISignatureTransfer.PermitBatchTransferFrom memory permitBatchData;
        {
            // Create the Permit2 PermitBatchTransferFrom struct
            // We need to create 2 token permissions (one for DS and one for PA)
            ISignatureTransfer.TokenPermissions[] memory permitted = new ISignatureTransfer.TokenPermissions[](2);
            permitted[0] = ISignatureTransfer.TokenPermissions({token: address(dsToken), amount: dsAmounts[0]});
            permitted[1] = ISignatureTransfer.TokenPermissions({token: address(pa), amount: paAmounts[0]});

            permitBatchData =
                ISignatureTransfer.PermitBatchTransferFrom({permitted: permitted, nonce: nonce, deadline: deadline});
        }

        // Generate the batch permit signature
        bytes memory signature = getPermitBatchTransferSignature(
            permitBatchData, USER_PK, IPermit2(permit2).DOMAIN_SEPARATOR(), address(protectedUnitRouter)
        );

        IProtectedUnitRouter.BatchMintParams memory param;
        // Record initial balances
        uint256 startBalanceDS = dsToken.balanceOf(user);
        uint256 startBalancePA = pa.balanceOf(user);
        uint256 startBalancePU = protectedUnit.balanceOf(user);
        {
            // Create transfer details for the Permit2 call
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails =
                new ISignatureTransfer.SignatureTransferDetails[](2);
            transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
                to: address(protectedUnitRouter), // Transfer DS to the router
                requestedAmount: dsAmounts[0]
            });
            transferDetails[1] = ISignatureTransfer.SignatureTransferDetails({
                to: address(protectedUnitRouter), // Transfer PA to the router
                requestedAmount: paAmounts[0]
            });

            // Create the BatchMintParams struct
            param = IProtectedUnitRouter.BatchMintParams({
                protectedUnits: protectedUnits,
                amounts: amounts,
                permitBatchData: permitBatchData,
                transferDetails: transferDetails,
                signature: signature
            });
        }

        {
            // Call the batchMint function
            (uint256[] memory actualDsAmounts, uint256[] memory actualPaAmounts) = protectedUnitRouter.batchMint(param);

            // Check amounts returned
            assertEq(actualDsAmounts[0], dsAmounts[0]);
            assertEq(actualPaAmounts[0], paAmounts[0]);
        }
        // Check balances and total supply
        assertEq(protectedUnit.balanceOf(user), startBalancePU + mintAmount);
        assertEq(protectedUnit.totalSupply(), mintAmount);

        // Check user token balances decreased correctly
        assertEq(dsToken.balanceOf(user), startBalanceDS - dsAmounts[0]);
        assertEq(pa.balanceOf(user), startBalancePA - paAmounts[0]);

        // Check token balances in the ProtectedUnit contract
        assertEq(dsToken.balanceOf(address(protectedUnit)), dsAmounts[0]);
        assertEq(pa.balanceOf(address(protectedUnit)), paAmounts[0]);

        // Check router has no remaining tokens (all were transferred to ProtectedUnit or user
        assertEq(dsToken.balanceOf(address(protectedUnitRouter)), 0);
        assertEq(pa.balanceOf(address(protectedUnitRouter)), 0);

        vm.stopPrank();
    }

    function test_PreviewBatchBurn() public {
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

        address[] memory protectedUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        protectedUnits[0] = address(protectedUnit);
        amounts[0] = 50 * 1e18;

        uint256[] memory dsAmounts = new uint256[](1);
        uint256[] memory paAmounts = new uint256[](1);

        // Preview dissolving 50 tokens
        (dsAmounts, paAmounts,) = protectedUnitRouter.previewBatchBurn(protectedUnits, amounts);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmounts[0], 50 * 1e18);
        assertEq(paAmounts[0], 50 * 1e18);
    }

    function test_BatchDissolvingTokens() public {
        // Mint tokens first
        mintTokens();

        vm.startPrank(user);

        uint256 burnAmount = 50 * 1e18;

        address[] memory protectedUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        protectedUnits[0] = address(protectedUnit);
        amounts[0] = burnAmount;

        protectedUnit.approve(address(protectedUnitRouter), burnAmount);

        // Burn 50 tokens
        protectedUnitRouter.batchBurn(protectedUnits, amounts);

        // Check that the user's ProtectedUnit balance and contract's DS/PA balance decreased
        assertEq(protectedUnit.balanceOf(user), 50 * 1e18); // 100 - 50 = 50 tokens left
        assertEq(dsToken.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50
        assertEq(pa.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50

        vm.stopPrank();
    }

    function test_BatchBurnWithPermit() public {
        // Mint tokens first
        mintTokens();

        vm.startPrank(user);

        // Approve ProtectedUnit for permit2
        protectedUnit.approve(address(permit2), type(uint256).max);

        uint256 burnAmount = 50 * 1e18;

        address[] memory protectedUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        protectedUnits[0] = address(protectedUnit);
        amounts[0] = burnAmount;

        // Calculate token amounts to be received from burning
        (uint256[] memory dsAmounts, uint256[] memory paAmounts, uint256[] memory raAmounts) =
            protectedUnitRouter.previewBatchBurn(protectedUnits, amounts);

        // Set up nonce and deadline for Permit2
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 10 minutes;

        // Record initial balances
        uint256 startBalanceDS = dsToken.balanceOf(user);
        uint256 startBalancePA = pa.balanceOf(user);
        uint256 startBalancePU = protectedUnit.balanceOf(user);

        ISignatureTransfer.PermitBatchTransferFrom memory permitBatchData;
        {
            // Create the Permit2 PermitBatchTransferFrom struct
            ISignatureTransfer.TokenPermissions[] memory permitted = new ISignatureTransfer.TokenPermissions[](1);
            permitted[0] = ISignatureTransfer.TokenPermissions({token: address(protectedUnit), amount: burnAmount});

            permitBatchData =
                ISignatureTransfer.PermitBatchTransferFrom({permitted: permitted, nonce: nonce, deadline: deadline});
        }

        IProtectedUnitRouter.BatchBurnPermitParams memory param;
        {
            // Create transfer details for the Permit2 call
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails =
                new ISignatureTransfer.SignatureTransferDetails[](1);
            transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
                to: address(protectedUnitRouter),
                requestedAmount: burnAmount
            });

            // Generate the batch permit signature
            bytes memory signature = getPermitBatchTransferSignature(
                permitBatchData, USER_PK, IPermit2(permit2).DOMAIN_SEPARATOR(), address(protectedUnitRouter)
            );

            param = IProtectedUnitRouter.BatchBurnPermitParams({
                protectedUnits: protectedUnits,
                amounts: amounts,
                permitBatchData: permitBatchData,
                transferDetails: transferDetails,
                signature: signature
            });
        }

        {
            // Call the batchBurn function with permit
            (,,, uint256[] memory actualDsAmounts, uint256[] memory actualPaAmounts, uint256[] memory actualRaAmounts) =
                protectedUnitRouter.batchBurn(param);

            // Verify returned amounts match expected amounts
            assertEq(actualDsAmounts[0], dsAmounts[0]);
            assertEq(actualPaAmounts[0], paAmounts[0]);
            assertEq(actualRaAmounts[0], raAmounts[0]);
        }

        // Check that the user's ProtectedUnit balance decreased
        assertEq(protectedUnit.balanceOf(user), startBalancePU - burnAmount);

        // Check that user received the underlying tokens
        assertEq(dsToken.balanceOf(user), startBalanceDS + dsAmounts[0]);
        assertEq(pa.balanceOf(user), startBalancePA + paAmounts[0]);

        vm.stopPrank();
    }

    function test_BatchMintExcessTokensReturn() public {
        // Test minting by the user with excess tokens permitted
        vm.startPrank(user);

        // Approve tokens for Permit2
        dsToken.approve(address(permit2), USER_BALANCE);
        pa.approve(address(permit2), USER_BALANCE);

        // Mint 100 ProtectedUnit tokens
        uint256 mintAmount = 100 * 1e18;

        // Setup the Protected Units array
        address[] memory protectedUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        protectedUnits[0] = address(protectedUnit);
        amounts[0] = mintAmount;

        // Calculate token amounts needed for minting
        (uint256[] memory dsAmounts, uint256[] memory paAmounts) =
            protectedUnitRouter.previewBatchMint(protectedUnits, amounts);

        // Intentionally increase the request amount to test excess return
        uint256 requestedDs = dsAmounts[0] + 10 * 1e18; // 10 Additional DS tokens for approval
        uint256 requestedPa = paAmounts[0] + 15 * 1e18; // 15 Additional PA tokens for approval

        ISignatureTransfer.PermitBatchTransferFrom memory permitBatchData;
        {
            // Set up nonce and deadline
            uint256 nonce = 0;
            uint256 deadline = block.timestamp + 10 minutes;

            // Create the Permit2 PermitBatchTransferFrom struct with excess amounts
            ISignatureTransfer.TokenPermissions[] memory permitted = new ISignatureTransfer.TokenPermissions[](2);
            permitted[0] = ISignatureTransfer.TokenPermissions({token: address(dsToken), amount: requestedDs});
            permitted[1] = ISignatureTransfer.TokenPermissions({token: address(pa), amount: requestedPa});

            permitBatchData =
                ISignatureTransfer.PermitBatchTransferFrom({permitted: permitted, nonce: nonce, deadline: deadline});
        }

        // Generate the batch permit signature
        bytes memory signature = getPermitBatchTransferSignature(
            permitBatchData, USER_PK, IPermit2(permit2).DOMAIN_SEPARATOR(), address(protectedUnitRouter)
        );

        // Record initial balances
        uint256 startBalanceDS = dsToken.balanceOf(user);
        uint256 startBalancePA = pa.balanceOf(user);
        uint256 startBalancePU = protectedUnit.balanceOf(user);

        IProtectedUnitRouter.BatchMintParams memory param;
        {
            // Create transfer details with excess amounts
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails =
                new ISignatureTransfer.SignatureTransferDetails[](2);
            transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
                to: address(protectedUnitRouter),
                requestedAmount: requestedDs
            });
            transferDetails[1] = ISignatureTransfer.SignatureTransferDetails({
                to: address(protectedUnitRouter),
                requestedAmount: requestedPa
            });

            param = IProtectedUnitRouter.BatchMintParams({
                protectedUnits: protectedUnits,
                amounts: amounts,
                permitBatchData: permitBatchData,
                transferDetails: transferDetails,
                signature: signature
            });
        }

        {
            // Call the batchMint function
            (uint256[] memory actualDsAmounts, uint256[] memory actualPaAmounts) = protectedUnitRouter.batchMint(param);

            // Double check that the exact excess was returned
            assertEq(startBalanceDS - dsToken.balanceOf(user), dsAmounts[0]);
            assertEq(startBalancePA - pa.balanceOf(user), paAmounts[0]);

            // Verify excess tokens were returned (user should have lost only the actual amounts needed)
            assertEq(dsToken.balanceOf(user), startBalanceDS - actualDsAmounts[0]);
            assertEq(pa.balanceOf(user), startBalancePA - actualPaAmounts[0]);
        }

        // Check ProtectedUnit balances
        assertEq(protectedUnit.balanceOf(user), startBalancePU + mintAmount);
        assertEq(protectedUnit.totalSupply(), mintAmount);
        vm.stopPrank();
    }

    function test_BatchBurnExcessTokensReturn() public {
        // Mint tokens first
        mintTokens();

        vm.startPrank(user);

        // Approve ProtectedUnit for permit2
        protectedUnit.approve(address(permit2), type(uint256).max);

        uint256 burnAmount = 50 * 1e18;
        uint256 totalPermitAmount = burnAmount + 20 * 1e18; // 20 excess PU to permit

        address[] memory protectedUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        protectedUnits[0] = address(protectedUnit);
        amounts[0] = burnAmount;

        ISignatureTransfer.PermitBatchTransferFrom memory permitBatchData;
        {
            // Set up nonce and deadline for Permit2
            uint256 nonce = 0;
            uint256 deadline = block.timestamp + 10 minutes;

            // Create the Permit2 PermitBatchTransferFrom struct with excess amount
            ISignatureTransfer.TokenPermissions[] memory permitted = new ISignatureTransfer.TokenPermissions[](1);
            permitted[0] =
                ISignatureTransfer.TokenPermissions({token: address(protectedUnit), amount: totalPermitAmount});

            permitBatchData =
                ISignatureTransfer.PermitBatchTransferFrom({permitted: permitted, nonce: nonce, deadline: deadline});
        }

        IProtectedUnitRouter.BatchBurnPermitParams memory param;
        {
            // Create transfer details with excess amount
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails =
                new ISignatureTransfer.SignatureTransferDetails[](1);
            transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
                to: address(protectedUnitRouter),
                requestedAmount: totalPermitAmount
            });

            // Generate the batch permit signature
            bytes memory signature = getPermitBatchTransferSignature(
                permitBatchData, USER_PK, IPermit2(permit2).DOMAIN_SEPARATOR(), address(protectedUnitRouter)
            );

            param = IProtectedUnitRouter.BatchBurnPermitParams({
                protectedUnits: protectedUnits,
                amounts: amounts,
                permitBatchData: permitBatchData,
                transferDetails: transferDetails,
                signature: signature
            });
        }

        {
            // Record initial balances
            uint256 startBalanceDS = dsToken.balanceOf(user);
            uint256 startBalancePA = pa.balanceOf(user);
            uint256 startBalanceRA = ra.balanceOf(user);
            uint256 startBalancePU = protectedUnit.balanceOf(user);

            // Call the batchBurn function with permit
            (,,, uint256[] memory actualDsAmounts, uint256[] memory actualPaAmounts, uint256[] memory actualRaAmounts) =
                protectedUnitRouter.batchBurn(param);

            // Check that only the specified amount was burned and the excess tokens were returned to user
            assertEq(protectedUnit.balanceOf(user), startBalancePU - burnAmount);

            // Check that user received the underlying tokens from burning
            assertEq(dsToken.balanceOf(user), startBalanceDS + actualDsAmounts[0]);
            assertEq(pa.balanceOf(user), startBalancePA + actualPaAmounts[0]);
            assertEq(ra.balanceOf(user), startBalanceRA + actualRaAmounts[0]);
        }

        // Verify no tokens are stuck in the router
        assertEq(protectedUnit.balanceOf(address(protectedUnitRouter)), 0);

        vm.stopPrank();
    }
}
