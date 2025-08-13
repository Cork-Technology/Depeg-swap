pragma solidity ^0.8.24;

import "./../../Helper.sol";

contract LpHelperTest is Helper {
    uint256 amount = 1 ether;
    DummyWETH ra;
    DummyWETH pa;

    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();
        (ra, pa,) = initializeAndIssueNewDs(block.timestamp + 10 days);

        vm.deal(DEFAULT_ADDRESS, 1_000_000_000 ether);
        ra.deposit{value: 1_000_000_000 ether}();
        ra.approve(address(moduleCore), 1_000_000_000 ether);

        vm.deal(DEFAULT_ADDRESS, 1_000_000 ether);
        pa.deposit{value: 1_000_000 ether}();
        pa.approve(address(moduleCore), 1_000_000 ether);

        moduleCore.depositLv(defaultCurrencyId, amount, 0, 0);
    }

    function testGetReserveFromLpAddress() external {
        (address ct,) = moduleCore.swapAsset(defaultCurrencyId, 1);

        (uint256 expectedRaReserve, uint256 expectedCtReserve) = hook.getReserves(address(ra), ct);
        address lp = hook.getLiquidityToken(address(ra), ct);

        (uint256 raReserve, uint256 ctReserve) = lpHelper.getReserve(lp);

        assertEq(raReserve, expectedRaReserve);
        assertEq(ctReserve, expectedCtReserve);
    }

    function testGetReserveFromId() external {
        (address ct,) = moduleCore.swapAsset(defaultCurrencyId, 1);

        (uint256 expectedRaReserve, uint256 expectedCtReserve) = hook.getReserves(address(ra), ct);

        (uint256 raReserve, uint256 ctReserve) = lpHelper.getReserve(defaultCurrencyId);

        assertEq(raReserve, expectedRaReserve);
        assertEq(ctReserve, expectedCtReserve);
    }

    function testGetReserveWithEpoch() external {
        (address ct,) = moduleCore.swapAsset(defaultCurrencyId, 1);

        (uint256 expectedRaReserve, uint256 expectedCtReserve) = hook.getReserves(address(ra), ct);

        (uint256 raReserve, uint256 ctReserve) = lpHelper.getReserve(defaultCurrencyId, 1);

        assertEq(raReserve, expectedRaReserve);
        assertEq(ctReserve, expectedCtReserve);
    }

    function testGetLpToken() external {
        (address ct,) = moduleCore.swapAsset(defaultCurrencyId, 1);

        (uint256 expectedRaReserve, uint256 expectedCtReserve) = hook.getReserves(address(ra), ct);
        address expectedLp = hook.getLiquidityToken(address(ra), ct);

        address lp = lpHelper.getLpToken(defaultCurrencyId);

        assertEq(lp, expectedLp);
    }

    function testGetLpTokenWithEpoch() external {
        (address ct,) = moduleCore.swapAsset(defaultCurrencyId, 1);

        (uint256 expectedRaReserve, uint256 expectedCtReserve) = hook.getReserves(address(ra), ct);
        address expectedLp = hook.getLiquidityToken(address(ra), ct);

        address lp = lpHelper.getLpToken(defaultCurrencyId, 1);

        assertEq(lp, expectedLp);
    }
}
