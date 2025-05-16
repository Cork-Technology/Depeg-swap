pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {DummyWETH} from "./../../../../contracts/dummy/DummyWETH.sol";
import {Id, Pair, PairLibrary} from "./../../../../contracts/libraries/Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../../../../contracts/libraries/TransferHelper.sol";
import "./../../../../contracts/core/assets/Asset.sol";
import "forge-std/console.sol";
import "./../../../../contracts/interfaces/IErrors.sol";

contract PsmTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;

    uint256 public constant DEFAULT_DEPOSIT_AMOUNT = 10000 ether;
    uint256 public constant EXPIRY = 1 days;

    address user2 = address(30);
    address public lv;
    uint256 public dsId;

    uint256 depositAmount = 1 ether;

    Asset internal ds;
    Asset internal ct;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);
        deployModuleCore();

        (ra, pa,) = initializeAndIssueNewDs(EXPIRY, 1 ether);

        vm.deal(DEFAULT_ADDRESS, type(uint256).max);

        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        vm.stopPrank();

        vm.startPrank(user2);

        vm.deal(user2, type(uint256).max);
        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        vm.stopPrank();
        vm.startPrank(DEFAULT_ADDRESS);

        ra.approve(address(moduleCore), type(uint256).max);

        moduleCore.depositLv(defaultCurrencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0, 0, block.timestamp);
    }

    function setupDifferentDecimals(uint8 raDecimals, uint8 paDecimals) internal returns (uint8, uint8) {
        // bound decimals to minimum of 18 and max of 64
        raDecimals = uint8(bound(raDecimals, TARGET_DECIMALS, MAX_DECIMALS));
        paDecimals = uint8(bound(paDecimals, TARGET_DECIMALS, MAX_DECIMALS));

        (ra, pa, defaultCurrencyId) = initializeAndIssueNewDs(EXPIRY, raDecimals, paDecimals);

        (address _ct, address _ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        ds = Asset(_ds);
        ct = Asset(_ct);

        vm.deal(DEFAULT_ADDRESS, type(uint256).max);
        ra.deposit{value: type(uint256).max}();

        vm.deal(DEFAULT_ADDRESS, type(uint256).max);
        pa.deposit{value: type(uint256).max}();

        ra.approve(address(moduleCore), type(uint256).max);
        pa.approve(address(moduleCore), type(uint256).max);

        ds.approve(address(moduleCore), type(uint256).max);
        ct.approve(address(moduleCore), type(uint256).max);

        return (raDecimals, paDecimals);
    }

    function test_depositPsm() public {
        vm.startPrank(DEFAULT_ADDRESS);
        ra.approve(address(moduleCore), 1 ether);

        (uint256 received, uint256 exchangeRate) = moduleCore.depositPsm(defaultCurrencyId, 1 ether);

        vm.assertEq(received, 1 ether);
        vm.assertEq(exchangeRate, defaultExchangeRate(), "Exchange rate should match default");

        vm.stopPrank();
    }

    function testFuzz_depositPsm(uint8 raDecimals, uint8 paDecimals) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);
        vm.resetGasMetering();

        depositAmount = TransferHelper.normalizeDecimals(depositAmount, TARGET_DECIMALS, raDecimals);

        (uint256 received,) = moduleCore.depositPsm(defaultCurrencyId, depositAmount);

        // regardless of the amount, the received amount would be in 18 decimals
        vm.assertEq(received, 1 ether);
    }

    function testFuzz_redeemDs(uint8 raDecimals, uint8 paDecimals, uint256 rates) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);
        rates = bound(rates, 0.9 ether, 1 ether);

        corkConfig.updatePsmRate(defaultCurrencyId, rates);
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);

        depositAmount = TransferHelper.normalizeDecimals(depositAmount, TARGET_DECIMALS, raDecimals);

        (uint256 received, uint256 exchangeRate) = moduleCore.depositPsm(defaultCurrencyId, depositAmount);

        uint256 redeemAmount = 1 ether * 1e18 / rates;

        redeemAmount = TransferHelper.normalizeDecimals(redeemAmount, TARGET_DECIMALS, paDecimals);

        (received,,,) = moduleCore.redeemRaWithDsPa(defaultCurrencyId, 1, redeemAmount);

        uint256 expectedAmount = TransferHelper.normalizeDecimals(1 ether, TARGET_DECIMALS, raDecimals);
        uint256 acceptableDelta = TransferHelper.normalizeDecimals(1, TARGET_DECIMALS, raDecimals);

        vm.assertApproxEqAbs(received, expectedAmount, acceptableDelta);
    }

    function testFuzz_redeemCt(uint8 raDecimals, uint8 paDecimals, uint256 rates) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        rates = bound(rates, 0.9 ether, 1 ether);

        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);
        corkConfig.updatePsmRate(defaultCurrencyId, rates);

        depositAmount = TransferHelper.normalizeDecimals(depositAmount, TARGET_DECIMALS, raDecimals);

        (uint256 received, uint256 exchangeRate) = moduleCore.depositPsm(defaultCurrencyId, depositAmount);

        // we redeem half of the deposited amount
        uint256 redeemAmount = 0.5 ether * 1e18 / rates;

        redeemAmount = TransferHelper.normalizeDecimals(redeemAmount, TARGET_DECIMALS, paDecimals);

        (received,,,) = moduleCore.redeemRaWithDsPa(defaultCurrencyId, 1, redeemAmount);
        //forward to expiry
        uint256 expiry = ds.expiry();
        vm.warp(expiry + 1);

        (uint256 accruedPa, uint256 accruedRa) = moduleCore.redeemWithExpiredCt(defaultCurrencyId, 1, 1 ether);

        uint256 expectedAmount = TransferHelper.normalizeDecimals(0.5 ether, TARGET_DECIMALS, raDecimals);
        uint256 acceptableDelta = TransferHelper.normalizeDecimals(1, TARGET_DECIMALS, raDecimals);

        vm.assertApproxEqAbs(received, expectedAmount, acceptableDelta);
    }

    function testFuzz_repurchase(uint8 raDecimals, uint8 paDecimals, uint256 rates) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        rates = bound(rates, 0.9 ether, 1 ether);

        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);
        corkConfig.updateRepurchaseFeeRate(defaultCurrencyId, 0);
        corkConfig.updatePsmRate(defaultCurrencyId, rates);

        depositAmount = TransferHelper.normalizeDecimals(depositAmount, TARGET_DECIMALS, raDecimals);

        (uint256 received, uint256 exchangeRate) = moduleCore.depositPsm(defaultCurrencyId, depositAmount);

        // we redeem half of the deposited amount
        uint256 redeemAmount = 0.5 ether * 1e18 / rates;

        redeemAmount = TransferHelper.normalizeDecimals(redeemAmount, TARGET_DECIMALS, paDecimals);

        (received,,,) = moduleCore.redeemRaWithDsPa(defaultCurrencyId, 1, redeemAmount);

        // and werepurchase half of the redeemed amount
        uint256 repurchaseAmount = 0.25 ether * rates / 1 ether;

        uint256 adjustedRepurchaseAmount =
            TransferHelper.normalizeDecimals(repurchaseAmount, TARGET_DECIMALS, raDecimals);

        (, uint256 receivedPa, uint256 receivedDs,,,) =
            moduleCore.repurchase(defaultCurrencyId, adjustedRepurchaseAmount);

        uint256 expectedAmount = TransferHelper.normalizeDecimals(0.25 ether, TARGET_DECIMALS, paDecimals);
        uint256 acceptableDelta = TransferHelper.normalizeDecimals(1, TARGET_DECIMALS, paDecimals);

        vm.assertApproxEqAbs(receivedPa, expectedAmount, acceptableDelta);
        vm.assertApproxEqAbs(receivedDs, repurchaseAmount, acceptableDelta);
    }

    function testFuzz_redeemCtDs(uint8 raDecimals, uint8 paDecimals) external {
        (raDecimals, paDecimals) = setupDifferentDecimals(raDecimals, paDecimals);

        depositAmount = TransferHelper.normalizeDecimals(depositAmount, TARGET_DECIMALS, raDecimals);

        (uint256 received, uint256 exchangeRate) = moduleCore.depositPsm(defaultCurrencyId, depositAmount);

        uint256 expectedReceived = 1 ether;

        vm.assertEq(received, expectedReceived);

        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        // approve
        IERC20(ct).approve(address(moduleCore), type(uint256).max);
        IERC20(ds).approve(address(moduleCore), type(uint256).max);

        uint256 ra = moduleCore.returnRaWithCtDs(defaultCurrencyId, received);

        uint256 acceptableDelta = TransferHelper.normalizeDecimals(1, TARGET_DECIMALS, raDecimals);

        vm.assertApproxEqAbs(ra, depositAmount, acceptableDelta);
    }

    function test_exchangeRate() public {
        uint256 rate = moduleCore.exchangeRate(defaultCurrencyId);
        vm.assertEq(rate, defaultExchangeRate(), "Exchange rate should match default");
    }

    function test_availableForRepurchase() public {
        moduleCore.depositPsm(defaultCurrencyId, 1 ether);

        (uint256 _pa, uint256 ds, uint256 _dsId) = moduleCore.availableForRepurchase(defaultCurrencyId);
        vm.assertEq(_pa, 0);
        vm.assertEq(ds, 0);
        vm.assertEq(_dsId, 1);
    }

    function test_RevertRedeemRaWithDsPaWithInsufficientLiquidity() external {
        vm.startPrank(user2);
        ra.approve(address(moduleCore), 1 ether);
        (uint256 received, uint256 exchangeRate) = moduleCore.depositPsm(defaultCurrencyId, 1 ether);

        dsId = moduleCore.lastDsId(defaultCurrencyId);
        (address _ct, address _ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        ds = Asset(_ds);

        ds.approve(address(moduleCore), 20000 ether);
        pa.approve(address(moduleCore), 20000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.InsufficientLiquidity.selector, 7502249375312343829335, 9900000000000000000000
            )
        );
        moduleCore.redeemRaWithDsPa(defaultCurrencyId, dsId, 10000 ether);
        vm.stopPrank();
    }

    function defaultExchangeRate() internal pure override returns (uint256) {
        return 1.0 ether;
    }
}
