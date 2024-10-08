pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../../contracts/libraries/MathHelper.sol";

contract VaultRedeemTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 10000 ether;
    uint256 redemptionFeePercentage = 10 ether;

    uint256 public dsId;

    address public lv;
    address user2 = address(30);
    address ds;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 1 days, redemptionFeePercentage);
        vm.deal(DEFAULT_ADDRESS, type(uint256).max);

        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), type(uint256).max);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);

        // save initial data
        lv = assetFactory.getLv(address(ra), address(pa));
        dsId = moduleCore.lastDsId(currencyId);
        (, ds) = moduleCore.swapAsset(currencyId, 1);
        Asset(ds).approve(address(moduleCore), type(uint256).max);
        pa.approve(address(moduleCore), type(uint256).max);
    }

    function testFuzz_redeemDs(uint256 redeemAmount) external {
        redeemAmount = bound(redeemAmount, 0.1 ether, DEFAULT_DEPOSIT_AMOUNT);

        (uint256 assets, uint256 fee, uint256 feePercentage) =
            moduleCore.previewRedeemRaWithDs(currencyId, dsId, redeemAmount);

        vm.assertEq(feePercentage, redemptionFeePercentage);
        uint256 expectedFee = MathHelper.calculatePercentageFee(feePercentage, redeemAmount);

        vm.assertEq(fee, expectedFee);
        vm.assertEq(assets, redeemAmount - fee);

        uint256 received;
        (received,, fee) = moduleCore.redeemRaWithDs(currencyId, dsId, redeemAmount);
        vm.assertEq(received, assets);
        vm.assertEq(fee, expectedFee);
    }
}
