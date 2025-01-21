pragma solidity ^0.8.24;

import "./../../../../contracts/libraries/HedgeUnitMath.sol";
import "./../../../../contracts/interfaces/IHedgeUnit.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

/// solhint-disable
contract LiquidityMathTest is Test {
    function test_previewMint() external {
        uint256 reservePa = 10 ether;
        uint256 reserveDs = 5 ether;
        uint256 totalLiquidity = 10 ether;

        (uint256 amountDs, uint256 amountPa) = HedgeUnitMath.previewMint(1 ether, reservePa, reserveDs, totalLiquidity);

        vm.assertEq(amountDs, 0.5 ether);
        vm.assertEq(amountPa, 1 ether);
    }

    function test_normalizeDecimals() external {
        uint256 amount = 1000 ether;
        uint8 decimals = 18;

        uint256 normalizedAmount = HedgeUnitMath.normalizeDecimals(amount, 18, decimals);

        vm.assertEq(normalizedAmount, 1000 ether);

        decimals = 6;

        normalizedAmount = HedgeUnitMath.normalizeDecimals(amount, 18, decimals);

        vm.assertEq(normalizedAmount, 1000 ether / 1e12);

        decimals = 24;

        normalizedAmount = HedgeUnitMath.normalizeDecimals(amount, 18, decimals);

        vm.assertEq(normalizedAmount, 1000 ether * 1e6);
    }

    function test_addLiquidityFirst() external {
        uint256 reservePa = 0;
        uint256 reserveDs = 0;
        uint256 totalLiquidity = 0;

        uint256 amountPa = 1000 ether;
        uint256 amountDs = 1000 ether;

        uint256 liquidityMinted = HedgeUnitMath.mint(reservePa, totalLiquidity, amountPa, amountDs);

        vm.assertEq(liquidityMinted, 1000 ether);
    }

    function testRevert_WhenaddLiquidityFirstNoProportional() external {
        uint256 reservePa = 0;
        uint256 reserveDs = 0;
        uint256 totalLiquidity = 0;

        uint256 amountPa = 1000 ether;
        uint256 amountDs = 900 ether;

        vm.expectRevert(IHedgeUnit.InvalidAmount.selector);
        HedgeUnitMath.mint(reservePa, totalLiquidity, amountPa, amountDs);
    }

    function test_addLiquiditySubsequent() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 amountPa = 1000 ether;
        uint256 amountDs = 900 ether;

        uint256 liquidityMinted = HedgeUnitMath.mint(reservePa, totalLiquidity, amountPa, amountDs);

        vm.assertApproxEqAbs(liquidityMinted, 474.3416491 ether, 0.0001 ether);
    }

    function test_removeLiquidity() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 reserveRa = 100 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 liquidityAmount = 100 ether;
        (uint256 amountPa, uint256 amountDs, uint256 amountRa) =
            HedgeUnitMath.withdraw(reservePa, reserveDs, reserveRa, totalLiquidity, liquidityAmount);

        vm.assertApproxEqAbs(amountPa, 210.818 ether, 0.001 ether);
        vm.assertApproxEqAbs(amountDs, 189.736 ether, 0.001 ether);
        vm.assertApproxEqAbs(amountRa, 10.54092662 ether, 0.001 ether);

        liquidityAmount = totalLiquidity;

        (amountPa, amountDs, amountRa) =
            HedgeUnitMath.withdraw(reservePa, reserveDs, reserveRa, totalLiquidity, liquidityAmount);

        vm.assertEq(amountPa, 2000 ether);
        vm.assertEq(amountDs, 1800 ether);
        vm.assertEq(amountRa, 100 ether);
    }

    function testRevert_removeLiquidityInvalidLiquidity() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 reserveRa = 100 ether;

        uint256 totalLiquidity = 948.6832 ether;

        uint256 liquidityAmount = 0;

        vm.expectRevert();
        HedgeUnitMath.withdraw(reservePa, reserveDs, reserveRa, totalLiquidity, liquidityAmount);
    }

    function testRevert_removeLiquidityNoLiquidity() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 reserveRa = 100 ether;
        uint256 totalLiquidity = 0;

        uint256 liquidityAmount = 100 ether;

        vm.expectRevert();
        HedgeUnitMath.withdraw(reservePa, reserveDs, reserveRa, totalLiquidity, liquidityAmount);
    }

    function testFuzz_proportionalAmount(uint256 amountPa) external {
        amountPa = bound(amountPa, 1 ether, 100000 ether);

        uint256 reservePa = 1000 ether;
        uint256 reserveDs = 2000 ether;

        uint256 amountDs = HedgeUnitMath.getProportionalAmount(amountPa, reservePa, reserveDs);

        vm.assertEq(amountDs, amountPa * 2);
    }
}
