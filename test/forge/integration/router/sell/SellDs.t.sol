pragma solidity ^0.8.24;

import "../../../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "../../../Helper.sol";
import {DummyWETH} from "../../../../../contracts/dummy/DummyWETH.sol";
import "../../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "../../../../../contracts/libraries/Pair.sol";
import "../../../../../contracts/interfaces/IPSMcore.sol";
import "../../../../../contracts/interfaces/IDsFlashSwapRouter.sol";
import "forge-std/console.sol";

contract SellDsTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    address ct;
    address ds;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 1900 ether;

    uint256 end = block.timestamp + 10 days;
    uint256 current = block.timestamp + 1 days;

    uint256 public dsId;

    function defaultInitialDsPrice() internal pure virtual override returns (uint256) {
        return 0.1 ether;
    }

    function defaultExchangeRate() internal pure virtual override returns (uint256) {
        return 1.1 ether;
    }

    function setUp() public virtual {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(end);

        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);

        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        ra.approve(address(moduleCore), 100_000_000_000 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0);

        dsId = moduleCore.lastDsId(currencyId);
        (ct,ds) = moduleCore.swapAsset(currencyId, dsId);
    }

    function test_sellDS() public virtual {
        ra.approve(address(flashSwapRouter), type(uint256).max);

        (uint256 raReserve, uint256 ctReserve) = hook.getReserves(address(ra), address(ct));

        uint256 amount = 5 ether;
        
        Asset(ds).approve(address(flashSwapRouter), amount);

        uint256 balanceRaBefore = ra.balanceOf(DEFAULT_ADDRESS);
        vm.warp(current);

        
        // TODO : figure out the out of whack gas consumption
        vm.pauseGasMetering();
        hook.updateBaseFeePercentage(address(ra), ct, 1 ether);
       
        uint256 amountOut = flashSwapRouter.swapDsforRa(
            currencyId, dsId, amount, 0, DEFAULT_ADDRESS, bytes(""), block.timestamp
        );

        uint256 balanceRaAfter = ra.balanceOf(DEFAULT_ADDRESS);

        vm.assertEq(balanceRaAfter - balanceRaBefore, amountOut);
    }
}
