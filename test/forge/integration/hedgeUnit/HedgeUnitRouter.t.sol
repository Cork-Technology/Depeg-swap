// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {HedgeUnit} from "../../../../contracts/core/assets/HedgeUnit.sol";
import {Liquidator} from "../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {DummyERCWithPermit} from "../../../../contracts/dummy/DummyERCWithPermit.sol";
import {Id} from "../../../../contracts/libraries/Pair.sol";
import {IHedgeUnitRouter} from "../../../../contracts/interfaces/IHedgeUnitRouter.sol";
import {Asset} from "../../../../contracts/core/assets/Asset.sol";

contract HedgeUnitRouterTest is Helper {
    Liquidator public liquidator;
    HedgeUnit public hedgeUnit;
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

        // Deploy the HedgeUnit contract
        corkConfig.deployHedgeUnit(currencyId, address(pa), address(ra), "DS/PA", INITIAL_MINT_CAP);
        hedgeUnit = HedgeUnit(hedgeUnitFactory.getHedgeUnitAddress(currencyId));

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
        address[] memory hedgeUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        
        hedgeUnits[0] = address(hedgeUnit);
        amounts[0] = 100 * 1e18;

        uint256[] memory dsAmounts = new uint256[](1);
        uint256[] memory paAmounts = new uint256[](1);

        // Preview minting 100 HedgeUnit tokens
        (dsAmounts, paAmounts) = hedgeUnitRouter.previewBatchMint(hedgeUnits, amounts);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmounts[0], 100 * 1e18);
        assertEq(paAmounts[0], 100 * 1e18);
    }

    function mintTokens() public {
        // Test_ minting by the user
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

    function test_BatchMint() public {
        // Test_ minting by the user
        vm.startPrank(user);

        // Mint 100 HedgeUnit tokens
        uint256 mintAmount = 100 * 1e18;

        // Permit token approvals to HedgeUnit contract
        (uint256 dsAmount, uint256 paAmount) = hedgeUnit.previewMint(mintAmount);
        bytes32 domain_separator = Asset(address(dsToken)).DOMAIN_SEPARATOR();
        uint256 deadline = block.timestamp + 10 days;

        bytes memory dsPermit = getCustomPermit(
            user,
            address(hedgeUnit),
            dsAmount,
            Asset(address(dsToken)).nonces(user),
            deadline,
            USER_PK,
            domain_separator,
            hedgeUnit.DS_PERMIT_MINT_TYPEHASH()
        );

        domain_separator = Asset(address(pa)).DOMAIN_SEPARATOR();

        bytes memory paPermit = getPermit(
            user,
            address(hedgeUnit),
            paAmount,
            Asset(address(pa)).nonces(user),
            deadline,
            USER_PK,
            domain_separator
        );

        IHedgeUnitRouter.BatchMintParams memory param = IHedgeUnitRouter.BatchMintParams({
            hedgeUnits: new address[](1),
            amounts: new uint256[](1),
            rawDsPermitSigs: new bytes[](1),
            rawPaPermitSigs: new bytes[](1),
            deadline: deadline
        });

        param.hedgeUnits[0] = address(hedgeUnit);
        param.amounts[0] = mintAmount;
        param.rawDsPermitSigs[0] = dsPermit;
        param.rawPaPermitSigs[0] = paPermit;
        hedgeUnitRouter.batchMint(param);

        // Check balances and total supply
        assertEq(hedgeUnit.balanceOf(user), mintAmount);
        assertEq(hedgeUnit.totalSupply(), mintAmount);

        // Check token balances in the contract
        assertEq(dsToken.balanceOf(address(hedgeUnit)), mintAmount);
        assertEq(pa.balanceOf(address(hedgeUnit)), mintAmount);

        vm.stopPrank();
    }

    function test_PreviewBatchBurn() public {
        // Mint tokens first
        dsToken.approve(address(hedgeUnit), USER_BALANCE);
        pa.approve(address(hedgeUnit), USER_BALANCE);
        
        uint256 mintAmount = 100 * 1e18;
        hedgeUnit.mint(mintAmount);

        address[] memory hedgeUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        
        hedgeUnits[0] = address(hedgeUnit);
        amounts[0] = 50 * 1e18;

        uint256[] memory dsAmounts = new uint256[](1);
        uint256[] memory paAmounts = new uint256[](1);

        // Preview dissolving 50 tokens
        (dsAmounts, paAmounts,) = hedgeUnitRouter.previewBatchBurn(hedgeUnits, amounts);

        // Check that the DS and PA amounts are correct
        assertEq(dsAmounts[0], 50 * 1e18);
        assertEq(paAmounts[0], 50 * 1e18);
    }

    function test_BatchDissolvingTokens() public {
        // Mint tokens first
        mintTokens();

        vm.startPrank(user);

        uint256 burnAmount = 50 * 1e18;

        address[] memory hedgeUnits = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        
        hedgeUnits[0] = address(hedgeUnit);
        amounts[0] = burnAmount;

        hedgeUnit.approve(address(hedgeUnitRouter), burnAmount);

        // Burn 50 tokens
        hedgeUnitRouter.batchBurn(hedgeUnits, amounts);

        // Check that the user's HedgeUnit balance and contract's DS/PA balance decreased
        assertEq(hedgeUnit.balanceOf(user), 50 * 1e18); // 100 - 50 = 50 tokens left
        assertEq(dsToken.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50
        assertEq(pa.balanceOf(user), USER_BALANCE - 50 * 1e18); // 500 - 50

        vm.stopPrank();
    }
}
