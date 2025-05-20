pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultRedeemTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 10000 ether;

    uint256 public dsId;

    address public lv;
    address user2 = address(30);
    uint256 _expiry = 1 days;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(_expiry, 1 ether);
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

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), type(uint256).max);

        // moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);
        moduleCore.depositLv(currencyId, DEFAULT_DEPOSIT_AMOUNT, 0, 0, 0, block.timestamp);

        // save initial data
        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());
        lv = assetFactory.getLv(address(ra), address(pa), DEFAULT_INITIAL_DS_PRICE, _expiry, exchangeRateProvider);
        dsId = moduleCore.lastDsId(currencyId);
    }

    function test_reissueMany() external {
        // wont' work because of the gas limit, so we ignore gas for this
        vm.pauseGasMetering();

        for (uint256 i = 0; i < 100; i++) {
            ff_expired();
        }
    }

    function defaultExchangeRate() internal pure override returns (uint256) {
        return 1.5 ether;
    }

    function ff_expired() internal {
        dsId = moduleCore.lastDsId(currencyId);
        (address ct,) = moduleCore.swapAsset(currencyId, dsId);
        uint256 expiry = Asset(ct).expiry();

        vm.warp(expiry);

        issueNewDs(currencyId);
    }
}
