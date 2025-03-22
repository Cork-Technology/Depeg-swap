pragma solidity ^0.8.24;

import {Helper} from "test/forge/Helper.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Asset} from "contracts/core/assets/Asset.sol";

contract RateUpdateTest is Helper {
    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);
        deployModuleCore();
        initializeAndIssueNewDs(100);
    }

    function test_shouldUpdateRateDownCorrectly() external {
        uint256 rate = moduleCore.exchangeRate(defaultCurrencyId);

        vm.assertEq(rate, 1 ether);

        corkConfig.updatePsmRate(defaultCurrencyId, 0.9 ether);

        rate = moduleCore.exchangeRate(defaultCurrencyId);

        vm.assertEq(rate, 0.9 ether);
    }

    function test_shouldUpdateRateUpCorrectlyOnNewIssuance() external {
        uint256 rate = moduleCore.exchangeRate(defaultCurrencyId);

        vm.assertEq(rate, 1 ether);

        initializeAndIssueNewDs(1000);

        corkConfig.updatePsmRate(defaultCurrencyId, 1.1 ether);

        rate = moduleCore.exchangeRate(defaultCurrencyId);

        vm.assertEq(rate, 1 ether);

        ff_expired();

        rate = moduleCore.exchangeRate(defaultCurrencyId);

        vm.assertEq(rate, 1.1 ether);
    }

    // ff to expiry and update infos
    function ff_expired() internal {
        (, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        // fast forward to expiry
        uint256 expiry = Asset(ds).expiry();
        vm.warp(expiry);
        issueNewDs(defaultCurrencyId);
    }

    function test_ShouldNotUpdateRateUpCorrectlyOnActive() external {
        uint256 rate = moduleCore.exchangeRate(defaultCurrencyId);

        vm.assertEq(rate, 1 ether);

        corkConfig.updatePsmRate(defaultCurrencyId, 1.1 ether);

        rate = moduleCore.exchangeRate(defaultCurrencyId);

        vm.assertEq(rate, 1 ether);
    }
}
