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

contract POCTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 10000 ether;
    uint256 redemptionFeePercentage = 5 ether;

    uint256 public dsId;

    address public lv;
    address user2 = address(30);
    address ds;
    uint256 _expiry = 1 days;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(_expiry, redemptionFeePercentage);
        vm.deal(DEFAULT_ADDRESS, type(uint256).max);

        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), type(uint256).max);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);

        // save initial data
        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());
        lv = assetFactory.getLv(address(ra), address(pa), DEFAULT_INITIAL_DS_PRICE, _expiry, exchangeRateProvider);
        dsId = moduleCore.lastDsId(currencyId);
        (, ds) = moduleCore.swapAsset(currencyId, 1);
        Asset(ds).approve(address(moduleCore), type(uint256).max);
        pa.approve(address(moduleCore), type(uint256).max);
    }

    function test_POC() external {}
}
