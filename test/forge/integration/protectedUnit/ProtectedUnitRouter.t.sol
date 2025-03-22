// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "test/forge/Helper.sol";
import {ProtectedUnit} from "contracts/core/assets/ProtectedUnit.sol";
import {Liquidator} from "contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {DummyERCWithPermit} from "test/utils/dummy/DummyERCWithPermit.sol";
import {Id} from "contracts/libraries/Pair.sol";
import {IProtectedUnitRouter} from "contracts/interfaces/IProtectedUnitRouter.sol";
import {Asset} from "contracts/core/assets/Asset.sol";

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
        moduleCore.depositLv(currencyId, USER_BALANCE * 2, 0, 0);

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

    function test_BatchMint() public {
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

        IProtectedUnitRouter.BatchMintParams memory param = IProtectedUnitRouter.BatchMintParams({
            protectedUnits: new address[](1),
            amounts: new uint256[](1),
            rawDsPermitSigs: new bytes[](1),
            rawPaPermitSigs: new bytes[](1),
            deadline: deadline
        });

        param.protectedUnits[0] = address(protectedUnit);
        param.amounts[0] = mintAmount;
        param.rawDsPermitSigs[0] = dsPermit;
        param.rawPaPermitSigs[0] = paPermit;
        protectedUnitRouter.batchMint(param);

        // Check balances and total supply
        assertEq(protectedUnit.balanceOf(user), mintAmount);
        assertEq(protectedUnit.totalSupply(), mintAmount);

        // Check token balances in the contract
        assertEq(dsToken.balanceOf(address(protectedUnit)), mintAmount);
        assertEq(pa.balanceOf(address(protectedUnit)), mintAmount);

        vm.stopPrank();
    }

    function test_PreviewBatchBurn() public {
        // Mint tokens first
        dsToken.approve(address(protectedUnit), USER_BALANCE);
        pa.approve(address(protectedUnit), USER_BALANCE);

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
}
