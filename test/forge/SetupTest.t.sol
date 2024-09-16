pragma solidity ^0.8.24;

import {Helper} from "./Helper.sol";

contract SetupTest is Helper {
    function test_setupDeployUniSwapFactory() public {
        deployUniswapFactory(address(this), address(this));
        assertEq(uniswapFactory.feeToSetter(), address(this));
    }

    function test_setupDeployUniswapRouter() public {
        deployUniswapRouter(address(this), address(this));
        assertEq(uniswapRouter.factory(), address(this));
        assertEq(uniswapRouter.WETH(), address(weth));
    }

    function test_setupModuleCore() public {
        deployModuleCore();
    }
}
