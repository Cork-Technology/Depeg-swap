pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "./../../../../contracts/libraries/MathHelper.sol";
import "./../../Helper.sol";
import "forge-std/console.sol";
import {UD60x18, convert, add, mul, pow, sub, div, unwrap, ud} from "@prb/math/src/UD60x18.sol";

contract NavMathTest is Test {
    UD60x18 internal raReserve = convert(1000 ether);
    UD60x18 internal ctReserve = convert(1050 ether);

    function test_quote() external {
        uint256 raQuote = unwrap(MathHelper.calculatePriceQuote(ctReserve, raReserve, ud(0.9 ether)));

        vm.assertApproxEqAbs(raQuote, 1.044 ether, 0.001 ether);

        uint256 ctQuote = unwrap(MathHelper.calculatePriceQuote(raReserve, ctReserve, ud(0.9 ether)));

        vm.assertApproxEqAbs(ctQuote, 0.957 ether, 0.001 ether);
    }

    function test_calculateNav() external {
        UD60x18 marketValue = ud(2 ether);
        UD60x18 qty = ud(3 ether);

        uint256 nav = unwrap(MathHelper.calculateNav(marketValue, qty));

        vm.assertEq(nav, 6 ether);
    }

    function test_calculateInternalPrices() external {
        MathHelper.NavParams memory params = MathHelper.NavParams({
            reserveRa: 1000 ether,
            oneMinusT: 0.1 ether,
            reserveCt: 1050 ether,
            lpSupply: 1024 ether,
            lvSupply: 2050 ether,
            vaultCt: 1000 ether,
            vaultDs: 2050 ether,
            vaultLp: 1024 ether,
            vaultIdleRa: 15 ether
        });

        MathHelper.InternalPrices memory prices = MathHelper.calculateInternalPrice(params);
        vm.assertApproxEqAbs(unwrap(prices.ctPrice), 0.957 ether, 0.001 ether);
        vm.assertApproxEqAbs(unwrap(prices.raPrice), 1 ether, 0.001 ether);
        vm.assertApproxEqAbs(unwrap(prices.dsPrice), 0.042 ether, 0.001 ether);
    }

    function test_calculateNavCombined() external {
        MathHelper.NavParams memory params = MathHelper.NavParams({
            reserveRa: 1000 ether,
            oneMinusT: 0.1 ether,
            reserveCt: 1050 ether,
            lpSupply: 1024 ether,
            lvSupply: 2050 ether,
            vaultCt: 1000 ether,
            vaultDs: 2050 ether,
            vaultLp: 1024 ether,
            vaultIdleRa: 15 ether
        });

        (UD60x18 navLp, UD60x18 navCt, UD60x18 navDs, UD60x18 navIdleRa) = MathHelper.calculateNavCombined(params);
        vm.assertApproxEqAbs(unwrap(navLp), 2004.8909 ether, 0.0001 ether);
        vm.assertApproxEqAbs(unwrap(navCt), 957.03 ether, 0.01 ether);
        vm.assertApproxEqAbs(unwrap(navDs), 88.07 ether, 0.01 ether);
        vm.assertApproxEqAbs(unwrap(navIdleRa), 15 ether, 0.0001 ether);
    }

    function test_calculateLvMinted() external {
        MathHelper.NavParams memory params = MathHelper.NavParams({
            reserveRa: 1000 ether,
            oneMinusT: 0.1 ether,
            reserveCt: 1050 ether,
            lpSupply: 1024 ether,
            lvSupply: 2050 ether,
            vaultCt: 1000 ether,
            vaultDs: 2050 ether,
            vaultLp: 1024 ether,
            vaultIdleRa: 15 ether
        });
        uint256 nav = MathHelper.calculateNav(params);
        uint256 minted = MathHelper.calculateDepositLv(nav, 1 ether, params.lvSupply);
        vm.assertApproxEqAbs(minted, 0.668 ether, 0.01 ether);
    }

    function test_Claim() external {
        MathHelper.RedeemParams memory params = MathHelper.RedeemParams({
            amountLvClaimed: 10 ether,
            totalLvIssued: 100 ether,
            totalVaultLp: 450 ether,
            totalVaultCt: 300 ether,
            totalVaultDs: 700 ether,
            totalVaultPA: 24 ether,
            totalVaultIdleRa: 15 ether
        });

        MathHelper.RedeemResult memory result = MathHelper.calculateRedeemLv(params);

        vm.assertEq(result.ctReceived, 30 ether);
        vm.assertEq(result.dsReceived, 70 ether);
        vm.assertEq(result.lpLiquidated, 45 ether);
        vm.assertEq(result.idleRaReceived, 1.5 ether);
        vm.assertEq(result.paReceived, 2.4 ether);
    }
}
