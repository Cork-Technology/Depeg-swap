pragma solidity ^0.8.24;

import "./../../Helper.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract TokenName is Helper {
    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);
        // saturday, June 3, 2000 1:07:47 PM
        // 06/03/2000 @ 1:07:47pm
        vm.warp(960037567);
        deployModuleCore();
        initializeAndIssueNewDs(100);
    }

    function test_tokenNames() external {
        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        address lv = moduleCore.lvAsset(defaultCurrencyId);

        IERC20Metadata ctToken = IERC20Metadata(ct);
        IERC20Metadata dsToken = IERC20Metadata(ds);
        IERC20Metadata lvToken = IERC20Metadata(lv);

        vm.assertEq(ctToken.symbol(), "DWETH6CT-1");
        vm.assertEq(dsToken.symbol(), "DWETH6DS-1");
        vm.assertEq(lvToken.symbol(), "DWETH!LV-1");

        initializeAndIssueNewDs(1000);

        (ct, ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        lv = moduleCore.lvAsset(defaultCurrencyId);

        ctToken = IERC20Metadata(ct);
        dsToken = IERC20Metadata(ds);
        lvToken = IERC20Metadata(lv);

        vm.assertEq(ctToken.symbol(), "DWETH6CT-2");
        vm.assertEq(dsToken.symbol(), "DWETH6DS-2");
        vm.assertEq(lvToken.symbol(), "DWETH!LV-2");
    }
}
