pragma solidity ^0.8.24;

import {Helper} from "./Helper.sol";

contract SetupTest is Helper {
    function test_setupModuleCore() public {
        vm.startPrank(DEFAULT_ADDRESS);
        deployModuleCore();
        vm.stopPrank();
    }
}
