pragma solidity 0.8.24;

import {ModuleCore} from "./../../contracts/core/ModuleCore.sol";
import {AssetFactory} from "./../../contracts/core/assets/AssetFactory.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IUniswapV2Factory} from "./../../contracts/interfaces/uniswap-v2/factory.sol";
import {IUniswapV2Router02} from "./../../contracts/interfaces/uniswap-v2/RouterV2.sol";
import {CorkConfig} from "./../../contracts/core/CorkConfig.sol";
import {RouterState} from "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";

abstract contract Helper is Test {
    ModuleCore internal moduleCore;
    AssetFactory internal assetFactory;
    IUniswapV2Factory internal uniswapFactory;
    IUniswapV2Router02 internal uniswapRouter;
    CorkConfig internal corkConfig;
    RouterState internal flashSwapRouter;
    DummyWETH internal weth = new DummyWETH();

    // 1% base redemption fee
    uint256 internal DEFAULT_BASE_REDEMPTION_FEE = 1 ether;

    function deployAssetFactory() internal {
        assetFactory = new AssetFactory();
    }

    function initializeAssetFactory() internal {
        assetFactory.initialize(address(moduleCore));
    }

    function deployUniswapRouter(address uniswapfactory, address _flashSwapRouter) internal {
        bytes memory constructorArgs = abi.encode(uniswapfactory, weth, _flashSwapRouter);

        address addr = deployCode("test/helper/ext-abi/uni-v2-router.json", constructorArgs);

        console.logAddress(addr);

        require(addr != address(0), "Router deployment failed");

        uniswapRouter = IUniswapV2Router02(addr);
    }

    function deployUniswapFactory(address feeToSetter, address _flashSwapRouter) internal {
        bytes memory constructorArgs = abi.encode(feeToSetter, _flashSwapRouter);

        address addr = deployCode("test/helper/ext-abi/uni-v2-factory.json", constructorArgs);

        uniswapFactory = IUniswapV2Factory(addr);
    }

    function deployConfig() internal {
        corkConfig = new CorkConfig();
    }

    function initializeConfig() internal {
        corkConfig.setModuleCore(address(moduleCore));
    }

    function deployFlashSwapRouter() internal {
        flashSwapRouter = new RouterState();
    }

    function initializeFlashSwapRouter() internal {
        flashSwapRouter.initialize(address(corkConfig), address(moduleCore), address(uniswapRouter));
    }

    function deployModuleCore() internal {
        deployConfig();
        deployFlashSwapRouter();
        deployAssetFactory();
        deployUniswapFactory(address(0), address(flashSwapRouter));
        deployUniswapRouter(address(uniswapFactory), address(flashSwapRouter));

        moduleCore = new ModuleCore(
            address(assetFactory),
            address(uniswapFactory),
            address(flashSwapRouter),
            address(uniswapRouter),
            address(corkConfig),
            DEFAULT_BASE_REDEMPTION_FEE
        );
        initializeAssetFactory();
        initializeConfig();
        initializeFlashSwapRouter();
    }

    function deployModuleCore(uint256 psmBaseRedemptionFee) internal {
        deployConfig();
        deployFlashSwapRouter();
        deployAssetFactory();
        deployUniswapFactory(address(0), address(flashSwapRouter));
        deployUniswapRouter(address(uniswapFactory), address(flashSwapRouter));

        moduleCore = new ModuleCore(
            address(assetFactory),
            address(uniswapFactory),
            address(flashSwapRouter),
            address(uniswapRouter),
            address(corkConfig),
            psmBaseRedemptionFee
        );
        initializeAssetFactory();
        initializeConfig();
        initializeFlashSwapRouter();
    }
}
