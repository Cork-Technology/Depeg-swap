pragma solidity ^0.8.24;

import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract PsmCoreTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public constant DEFAULT_DEPOSIT_AMOUNT = 10000 ether;
    uint256 public constant EXPIRY = 1 days;

    address user2 = address(30);
      address public lv;
      uint256 public dsId;

     function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(EXPIRY, 1 ether);
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

        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0);
    }

    function test_depositPsm() public {
       
        vm.startPrank(DEFAULT_ADDRESS);
        ra.approve(address(moduleCore), 1 ether);

      
        (uint256 received, uint256 exchangeRate) = moduleCore.depositPsm(currencyId, 1 ether);

        assertTrue(received > 0, "Should receive tokens");
        assertEq(exchangeRate, defaultExchangeRate(), "Exchange rate should match default");

        vm.stopPrank();
    }

    function test_redeemWithDs() public {
       
        vm.startPrank(DEFAULT_ADDRESS);
        ra.approve(address(moduleCore), type(uint256).max );

        uint256 _dsId = moduleCore.lastDsId(currencyId);
     
        (uint256 received, uint256 exchangeRate, uint256 fee) = moduleCore.redeemRaWithDs(currencyId, _dsId, 1000 ether);

        assertTrue(received > 0, "Should receive tokens");
        assertTrue(fee > 0, "Should have fee");

        vm.stopPrank();
    }

    function test_exchangeRate() public {
        uint256 rate = moduleCore.exchangeRate(currencyId);
        assertEq(rate, defaultExchangeRate(), "Exchange rate should match default");
    }

    function test_availableForRepurchase() public {
        
        moduleCore.depositPsm(currencyId, 1 ether);

        (uint256 _pa, uint256 ds, uint256 _dsId) = moduleCore.availableForRepurchase(currencyId);

        assertTrue(_pa > 0, "PA should be available");
        assertTrue(ds > 0, "DS should be available");
        assertTrue(_dsId > 0, "DS ID should be valid");
    }

    function defaultExchangeRate() internal pure override returns (uint256) {
        return 1.0 ether;
    }
}