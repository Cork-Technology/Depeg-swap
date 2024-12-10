pragma solidity ^0.8.24;

import "./../../../../contracts/libraries/HedgeUnitMath.sol";
import "./../../../../contracts/interfaces/IHedgeUnit.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

/// solhint-disable
contract LiquidityMathTest is Test {
    function test_addLiquidityFirst() external {
        uint256 reservePa = 0;
        uint256 reserveDs = 0;
        uint256 totalLiquidity = 0;

        uint256 amountPa = 1000 ether;
        uint256 amountDs = 1000 ether;

        (uint256 newReservePa, uint256 newReserveDs, uint256 liquidityMinted) =
            HedgeUnitLiquidityMath.addLiquidity(reservePa, reserveDs, totalLiquidity, amountPa, amountDs);

        vm.assertEq(newReservePa, amountPa);
        vm.assertEq(newReserveDs, amountDs);

        vm.assertEq(liquidityMinted, 1000 ether);
    }

    function testRevert_WhenaddLiquidityFirstNoProportional() external {
        uint256 reservePa = 0;
        uint256 reserveDs = 0;
        uint256 totalLiquidity = 0;

        uint256 amountPa = 1000 ether;
        uint256 amountDs = 900 ether;

        vm.expectRevert(IHedgeUnit.InvalidAmount.selector);
        HedgeUnitLiquidityMath.addLiquidity(reservePa, reserveDs, totalLiquidity, amountPa, amountDs);
    }

    function test_addLiquiditySubsequent() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 amountPa = 1000 ether;
        uint256 amountDs = 900 ether;

        (uint256 newReservePa, uint256 newReserveDs, uint256 liquidityMinted) =
            HedgeUnitLiquidityMath.addLiquidity(reservePa, reserveDs, totalLiquidity, amountPa, amountDs);

        vm.assertEq(newReservePa, amountPa + reservePa);
        vm.assertEq(newReserveDs, amountDs + reserveDs);

        vm.assertApproxEqAbs(liquidityMinted, 474.3416491 ether, 0.0001 ether);
    }

    function test_removeLiquidity() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 liquidityAmount = 100 ether;
        (uint256 amountPa, uint256 amountDs, uint256 newReservePa, uint256 newReserveDs) =
            HedgeUnitLiquidityMath.removeLiquidity(reservePa, reserveDs, totalLiquidity, liquidityAmount);

        vm.assertApproxEqAbs(amountPa, 210.818 ether, 0.001 ether);
        vm.assertApproxEqAbs(amountDs, 189.736 ether, 0.001 ether);
        vm.assertEq(newReservePa, 2000 ether - amountPa);
        vm.assertEq(newReserveDs, 1800 ether - amountDs);

        liquidityAmount = totalLiquidity;

        (amountPa, amountDs, newReservePa, newReserveDs) =
            HedgeUnitLiquidityMath.removeLiquidity(reservePa, reserveDs, totalLiquidity, liquidityAmount);

        vm.assertEq(amountPa, 2000 ether);
        vm.assertEq(amountDs, 1800 ether);
        vm.assertEq(newReservePa, 0);
        vm.assertEq(newReserveDs, 0);
    }

    function testRevert_removeLiquidityInvalidLiquidity() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 totalLiquidity = 948.6832 ether;

        uint256 liquidityAmount = 0;

        vm.expectRevert();
        HedgeUnitLiquidityMath.removeLiquidity(reservePa, reserveDs, totalLiquidity, liquidityAmount);
    }

    function testRevert_removeLiquidityNoLiquidity() external {
        uint256 reservePa = 2000 ether;
        uint256 reserveDs = 1800 ether;
        uint256 totalLiquidity = 0;

        uint256 liquidityAmount = 100 ether;

        vm.expectRevert();
        HedgeUnitLiquidityMath.removeLiquidity(reservePa, reserveDs, totalLiquidity, liquidityAmount);
    }

    function testFuzz_proportionalAmount(uint256 amountPa) external {
        amountPa = bound(amountPa, 1 ether, 100000 ether);

        uint256 reservePa = 1000 ether;
        uint256 reserveDs = 2000 ether;

        uint256 amountDs = HedgeUnitLiquidityMath.getProportionalAmount(amountPa, reservePa, reserveDs);

        vm.assertEq(amountDs, amountPa * 2);
    }

    function test_dustInferOptimalAmount() external {
        uint256 amount0Desired = 1 ether;

        uint256 amount1Desired = 5 ether;

        uint256 reservePa = 1000 ether;
        uint256 reserveDs = 2000 ether;

        (uint256 amountPa, uint256 amountDs) =
            HedgeUnitLiquidityMath.inferOptimalAmount(reservePa, reserveDs, amount0Desired, amount1Desired, 0, 0);

        // we only use 2 ether
        vm.assertEq(amountDs, 2 ether);

        amount1Desired = 0.5 ether;

        (amountPa, amountDs) =
            HedgeUnitLiquidityMath.inferOptimalAmount(reservePa, reserveDs, amount0Desired, amount1Desired, 0, 0);

        // we only use 0.25 ether
        vm.assertEq(amountPa, 0.25 ether);
        vm.assertEq(amountDs, amount1Desired);
    }
}
