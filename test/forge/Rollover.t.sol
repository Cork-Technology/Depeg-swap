pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";

contract RolloverTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    // we double the amount(should be 2050) since we're splitting CT when user deposit RA to the test default(50%)
    uint256 public DEFAULT_DEPOSIT_AMOUNT = 4100 ether;

    uint256 public dsId;

    address public ct;
    address public ds;

    uint256 internal DEFAULT_ADDRESS_PK = 1;
    address internal DEFAULT_ADDRESS_ROLLOVER = vm.rememberKey(DEFAULT_ADDRESS_PK);

    function beforeTestSetup(bytes4 testSelector) public pure returns (bytes[] memory beforeTestCalldata) {
        if (testSelector == this.test_RevertClaimRolloverTwice.selector) {
            beforeTestCalldata = new bytes[](2);

            beforeTestCalldata[0] = abi.encodeWithSelector(this.setUp.selector);
            beforeTestCalldata[1] = abi.encodeWithSelector(this.test_RolloverWork.selector);
        }
    }

    function defaultInitialArp() internal pure virtual override returns (uint256) {
        return 5 ether;
    }

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS_ROLLOVER);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 1 days);
        vm.deal(DEFAULT_ADDRESS_ROLLOVER, 100_000_000 ether);
        ra.deposit{value: 100000 ether}();
        pa.deposit{value: 100000 ether}();

        // save initial data
        fetchProtocolGeneralInfo();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), 100_000_000 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0);
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

        fetchProtocolGeneralInfo();
    }

    function test_RolloverWork() external {
        uint256 prevDsId = dsId;

        ff_expired();

        (uint256 ctReceived, uint256 dsReceived,) = moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, prevDsId);

        // verify that we have enough balance
        vm.assertEq(ctReceived, Asset(ds).balanceOf(DEFAULT_ADDRESS_ROLLOVER));
        vm.assertEq(dsReceived, Asset(ct).balanceOf(DEFAULT_ADDRESS_ROLLOVER));
    }

    function test_autoSellWorks() external {
        uint256 prevDsId = dsId;

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, true);

        ff_expired();

        (uint256 ctReceived, uint256 dsReceived,) = moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, prevDsId);

        vm.assertEq(dsReceived, 0);
        vm.assertEq(ctReceived, Asset(ct).balanceOf(DEFAULT_ADDRESS_ROLLOVER));
        vm.assertEq(0, Asset(ds).balanceOf(DEFAULT_ADDRESS_ROLLOVER));

        uint256 psmReserve = flashSwapRouter.getAssetPair(currencyId, dsId).psmReserve;
        uint256 lvReserve = flashSwapRouter.getAssetPair(currencyId, dsId).lvReserve;

        // we compare it to ctReceived because the amount that should've gone to the user
        // here goes to the flash swap router
        vm.assertEq(psmReserve, ctReceived);
        vm.assertEq(ctReceived, Asset(ds).balanceOf(address(flashSwapRouter)) - lvReserve);
    }

    function test_RolloverWorkWithPermit() external {
        uint256 prevDsId = dsId;
        bytes32 DOMAIN_SEPARATOR = Asset(ct).DOMAIN_SEPARATOR();

        uint256 deadline = block.timestamp + 10 days;

        bytes memory permit = getCustomPermit(
            DEFAULT_ADDRESS_ROLLOVER,
            address(moduleCore),
            DEFAULT_DEPOSIT_AMOUNT,
            Asset(ct).nonces(DEFAULT_ADDRESS_ROLLOVER),
            deadline,
            DEFAULT_ADDRESS_PK,
            DOMAIN_SEPARATOR,
            "rolloverCt"
        );

        ff_expired();

        (uint256 ctReceived, uint256 dsReceived,) = moduleCore.rolloverCt(
            currencyId, DEFAULT_ADDRESS_ROLLOVER, DEFAULT_DEPOSIT_AMOUNT, prevDsId, permit, deadline
        );

        vm.assertEq(ctReceived, Asset(ds).balanceOf(DEFAULT_ADDRESS_ROLLOVER));
        vm.assertEq(dsReceived, Asset(ct).balanceOf(DEFAULT_ADDRESS_ROLLOVER));
    }

    function test_claimAutoSellProfit() external {
        uint256 prevDsId = dsId;

        ra.approve(address(flashSwapRouter), 2 ether);
        // so that our trades are heavy
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry - 100);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, 1 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        uint256 amountOut = result.amountOut;

        uint256 HiyaCummulated = flashSwapRouter.getHiyaCumulated(currencyId);
        uint256 vHiyaCummulated = flashSwapRouter.getVhiyaCumulated(currencyId);

        ff_expired();

        // we fetch the Hiya after expiry so that it's calculated
        uint256 Hiya = flashSwapRouter.getHiya(currencyId);

        vm.assertNotEq(vHiyaCummulated, 0);
        vm.assertNotEq(HiyaCummulated, 0);

        // expected to be around 1% ARP
        vm.assertApproxEqAbs(Hiya, 0.017895624717812529 ether, 0.01 ether);

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, true);

        // rollover our CT
        (uint256 ctReceived, uint256 dsReceived,) = moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, prevDsId);

        // we autosell
        vm.assertEq(dsReceived, 0);

        result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, 1 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        amountOut = result.amountOut;

        uint256 rolloverProfit = moduleCore.getPsmPoolArchiveRolloverProfit(currencyId, dsId);
        vm.assertNotEq(rolloverProfit, 0);

        uint256 claims = IPSMcore(moduleCore).rolloverProfitRemaining(currencyId, dsId);
        vm.assertApproxEqAbs(claims, DEFAULT_DEPOSIT_AMOUNT, 1);

        (uint256 rolloverProfitReceived, uint256 rolloverDsReceived) =
            moduleCore.claimAutoSellProfit(currencyId, dsId, claims);

        claims = IPSMcore(moduleCore).rolloverProfitRemaining(currencyId, dsId);
        vm.assertEq(claims, 0);

        vm.assertEq(
            moduleCore.getPsmPoolArchiveRolloverProfit(currencyId, dsId), rolloverProfit - rolloverProfitReceived
        );

        vm.assertEq(Asset(ds).balanceOf(DEFAULT_ADDRESS_ROLLOVER) - amountOut, rolloverDsReceived);
    }

    function test_RevertClaimRolloverTwice() external {
        vm.expectRevert();

        moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, dsId - 1);
    }

    function test_RevertWhenNotExpired() external {
        vm.expectRevert();

        moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, dsId);
    }

    function test_RevertClaimBalanceNotEnough() external {
        // transfer some CT + DS to user, let that user claim rollover profit

        uint256 prevDsId = dsId;

        ra.approve(address(flashSwapRouter), 2 ether);

        // so that our trades are heavy
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry - 100);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, 1 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        uint256 amountOut = result.amountOut;

        uint256 HiyaCummulated = flashSwapRouter.getHiyaCumulated(currencyId);
        uint256 vHiyaCummulated = flashSwapRouter.getVhiyaCumulated(currencyId);

        ff_expired();

        // we fetch the Hiya after expiry so that it's calculated
        uint256 Hiya = flashSwapRouter.getHiya(currencyId);

        vm.assertNotEq(vHiyaCummulated, 0);
        vm.assertNotEq(HiyaCummulated, 0);

        // expected to be around 1% ARP
        vm.assertApproxEqAbs(Hiya, 0.017895624717812529 ether, 0.01 ether);

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, true);

        // rollover our CT
        (uint256 ctReceived, uint256 dsReceived,) = moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, prevDsId);

        // we autosell
        vm.assertEq(dsReceived, 0);

        result = flashSwapRouter.swapRaforDs(currencyId, dsId, 1 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams());
        amountOut = result.amountOut;

        uint256 rolloverProfit = moduleCore.getPsmPoolArchiveRolloverProfit(currencyId, dsId);
        vm.assertNotEq(rolloverProfit, 0);

        uint256 claims = IPSMcore(moduleCore).rolloverProfitRemaining(currencyId, dsId);
        vm.assertApproxEqAbs(claims, DEFAULT_DEPOSIT_AMOUNT, 1);
        // we transfer all the CT to the user
        Asset(ct).transfer(address(69), claims);

        // try to claim rollover profit, should fail
        vm.startPrank(address(69));
        vm.expectRevert();
        (uint256 rolloverProfitReceived, uint256 rolloverDsReceived) =
            moduleCore.claimAutoSellProfit(currencyId, dsId, claims);
        vm.stopPrank();
    }

    function test_rolloverSaleWorks() external {
        uint256 prevDsId = dsId;

        ra.approve(address(flashSwapRouter), 100 ether);

        // so that our trades are heavy
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry - 100);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, 1 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        uint256 amountOut = result.amountOut;

        uint256 HiyaCummulated = flashSwapRouter.getHiyaCumulated(currencyId);
        uint256 vHiyaCummulated = flashSwapRouter.getVhiyaCumulated(currencyId);

        ff_expired();

        // we fetch the Hiya after expiry so that it's calculated
        uint256 Hiya = flashSwapRouter.getHiya(currencyId);

        vm.assertNotEq(vHiyaCummulated, 0);
        vm.assertNotEq(HiyaCummulated, 0);

        // expected to be around 1% ARP
        vm.assertApproxEqAbs(Hiya, 0.017895624717812529 ether, 0.01 ether);

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, true);

        // rollover our CT
        (uint256 ctReceived, uint256 dsReceived,) = moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, prevDsId);

        // we autosell
        vm.assertEq(dsReceived, 0);

        vm.assertEq(true, flashSwapRouter.isRolloverSale(currencyId));

        // based on the Hiya = 0.017895624717812529 (~1% ARP) and t = 1
        uint256 expectedHPA = 0.017895624717812529 ether;

        // we disable graduale sale to get an accurate representation
        disableDsGradualSale();

        result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, expectedHPA, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        amountOut = result.amountOut;

        vm.assertApproxEqAbs(amountOut, 1 ether, 0.018 ether);

        result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, expectedHPA * 10, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        amountOut = result.amountOut;

        vm.assertApproxEqAbs(amountOut, 10 ether, 0.18 ether);
    }

    function test_RevertOutIsLessThanMin() external {
        uint256 prevDsId = dsId;

        ra.approve(address(flashSwapRouter), 100 ether);

        // so that our trades are heavy
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry - 100);

        IDsFlashSwapCore.SwapRaForDsReturn memory result = flashSwapRouter.swapRaforDs(
            currencyId, dsId, 1 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
        uint256 amountOut = result.amountOut;

        uint256 HiyaCummulated = flashSwapRouter.getHiyaCumulated(currencyId);
        uint256 vHiyaCummulated = flashSwapRouter.getVhiyaCumulated(currencyId);

        ff_expired();

        // we fetch the Hiya after expiry so that it's calculated
        uint256 Hiya = flashSwapRouter.getHiya(currencyId);

        vm.assertNotEq(vHiyaCummulated, 0);
        vm.assertNotEq(HiyaCummulated, 0);

        // expected to be around 1% ARP
        vm.assertApproxEqAbs(Hiya, 0.017895624717812529 ether, 0.01 ether);

        IPSMcore(moduleCore).updatePsmAutoSellStatus(currencyId, true);

        // rollover our CT
        (uint256 ctReceived, uint256 dsReceived,) = moduleCore.rolloverCt(currencyId, DEFAULT_DEPOSIT_AMOUNT, prevDsId);

        // we autosell
        vm.assertEq(dsReceived, 0);

        vm.assertEq(true, flashSwapRouter.isRolloverSale(currencyId));

        vm.expectRevert();
        flashSwapRouter.swapRaforDs(
            currencyId, dsId, Hiya, 1000000 ether, defaultBuyApproxParams(), defaultOffchainGuessParams()
        );
    }
}
