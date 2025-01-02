pragma solidity ^0.8.24;

import "../../../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "../../../Helper.sol";
import {DummyWETH} from "../../../../../contracts/dummy/DummyWETH.sol";
import "../../../../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "../../../../../contracts/libraries/Pair.sol";
import "../../../../../contracts/interfaces/IPSMcore.sol";
import "../../../../../contracts/interfaces/IDsFlashSwapRouter.sol";
import "forge-std/console.sol";

contract BasicFlashSwapTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 5_000_000 ether;

    uint256 public dsId;


    function defaultInitialDsPrice() internal pure virtual override returns (uint256) {
        return 0.001 ether;
    }

    function defaultExchangeRate() internal pure virtual override returns (uint256) {
        return 1.1 ether;
    }


    function setUp() public virtual {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(block.timestamp + 1 days);

        vm.deal(DEFAULT_ADDRESS, 100_000_000_000 ether);

        ra.deposit{value: 1_000_000_000 ether}();
        pa.deposit{value: 1_000_000_000 ether}();

        ra.approve(address(moduleCore), 100_000_000_000 ether);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0);

        dsId = moduleCore.lastDsId(currencyId);
    }


    function test_buyDS() public virtual {
        ra.approve(address(flashSwapRouter), type(uint256).max);

        uint256 amountOut = flashSwapRouter.swapRaforDs(currencyId, dsId, 1 ether, 0);
    }
}