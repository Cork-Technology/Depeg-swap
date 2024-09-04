pragma solidity 0.8.24;

import {ModuleCore} from "./../../contracts/core/ModuleCore.sol";
import {AssetFactory} from "./../../contracts/core/assets/AssetFactory.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IUniswapV2Factory} from "./../../contracts/interfaces/uniswap-v2/factory.sol";
import {IUniswapV2Router02} from "./../../contracts/interfaces/uniswap-v2/RouterV2.sol";

abstract contract Helper is Test {
    ModuleCore internal moduleCore;
    AssetFactory internal assetFactory;
    IUniswapV2Factory internal uniswapFactory;
    IUniswapV2Router02 internal uniswapRouter;

    function deployAssetFactory() internal {
        assetFactory = new AssetFactory();
    }

    function deployUniswapRouter(
        address uniswapfactory,
        address weth,
        address flashSwapRouter
    ) internal {
        bytes memory constructorArgs = abi.encode(
            uniswapfactory,
            weth,
            flashSwapRouter
        );

        address addr = deployCode(
            "test/helper/ext-abi/uni-v2-router.json",
            constructorArgs
        );

        console.logAddress(addr);

        require(addr != address(0), "Router deployment failed");

        uniswapRouter = IUniswapV2Router02(addr);
    }

    function deployUniswapFactory(
        address feeToSetter,
        address flashSwapRouter
    ) internal {
        bytes memory constructorArgs = abi.encode(feeToSetter, flashSwapRouter);

        address addr = deployCode(
            "test/helper/ext-abi/uni-v2-factory.json",
            constructorArgs
        );

        uniswapFactory = IUniswapV2Factory(addr);
    }

    // function deployModuleCore() internal returns (ModuleCore) {
    //     self = new ModuleCore();
    //     return self;
    // }
}
