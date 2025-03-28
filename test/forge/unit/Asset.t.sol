pragma solidity ^0.8.26;

import "./../Helper.sol";
import "./../../../contracts/dummy/DummyWETH.sol";
import "./../../../contracts/core/assets/Asset.sol";
import "./../../../contracts/libraries/Pair.sol";

contract AssetTest is Helper {
    DummyWETH ra;
    DummyWETH pa;
    Asset ct;
    Asset ds;
    Asset lv;

    uint256 public constant depositAmount = 1 ether;
    uint256 public constant redeemAmount = 0.5 ether;

    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa,) = initializeAndIssueNewDs(block.timestamp + 1 days);
        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);
        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        ra.approve(address(moduleCore), 100_000_000_000 ether);
        pa.approve(address(moduleCore), 100_000_000_000 ether);

        moduleCore.depositPsm(defaultCurrencyId, depositAmount);

        (address _ct, address _ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        ct = Asset(_ct);
        ds = Asset(_ds);
        lv = Asset(moduleCore.lvAsset(defaultCurrencyId));
    }

    function fetchProtocolGeneralInfo() internal {
        uint256 dsId = moduleCore.lastDsId(defaultCurrencyId);
        (address _ct, address _ds) = moduleCore.swapAsset(defaultCurrencyId, dsId);
        ct = Asset(_ct);
        ds = Asset(_ds);
        ds.approve(address(moduleCore), 100_000_000_000 ether);
    }

    function assertReserve(Asset token, uint256 expectedRa, uint256 expectedPa) internal {
        (uint256 ra, uint256 pa) = token.getReserves();

        vm.assertEq(ra, expectedRa);
        vm.assertEq(pa, expectedPa);
    }

    function testResolution() external {
        // ct, should return current reserve
        assertReserve(ct, depositAmount, 0);

        // ds, should return current reserve
        assertReserve(ds, depositAmount, 0);

        assertReserve(lv, depositAmount, 0);

        // fast forward to expiry
        uint256 expiry = ds.expiry();
        vm.warp(expiry);

        issueNewDs(defaultCurrencyId);

        assertReserve(ct, depositAmount, 0);
        assertReserve(ds, depositAmount, 0);
        assertReserve(lv, 0, 0);

        Asset(ct).approve(address(moduleCore), type(uint128).max);
        moduleCore.rolloverExpiredCt(defaultCurrencyId, depositAmount, 1);

        assertReserve(ct, 0, 0);
        assertReserve(ds, 0, 0);
        assertReserve(lv, depositAmount, 0);

        fetchProtocolGeneralInfo();

        assertReserve(ct, depositAmount, 0);
        assertReserve(ds, depositAmount, 0);
        assertReserve(lv, depositAmount, 0);

        moduleCore.redeemRaWithDsPa(defaultCurrencyId, 2, redeemAmount);

        assertReserve(ct, redeemAmount, redeemAmount);
        assertReserve(ds, redeemAmount, redeemAmount);
        assertReserve(lv, redeemAmount, redeemAmount);
    }
}
