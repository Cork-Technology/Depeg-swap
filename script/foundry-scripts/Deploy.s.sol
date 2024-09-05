pragma solidity 0.8.24;

import {IUniswapV2Factory} from "uniswap-v2/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {DummyWETH} from "../../contracts/dummy/DummyWETH.sol";

contract DeployScript is Script {
    string constant v2FactoryArtifact = "test/helper/ext-abi/uni-v2-factory.json";
    string constant v2RouterArtifact = "test/helper/ext-abi/uni-v2-router.json";

    IUniswapV2Factory public factory;
    IUniswapV2Router02 public univ2Router;

    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;

    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PRECENTAGE");

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the WETH contract
        DummyWETH weth = new DummyWETH();
        console.log("WETH                            : ", address(weth));

        // Deploy the Asset Factory implementation (logic) contract
        AssetFactory assetFactoryImplementation = new AssetFactory();
        console.log("Asset Factory Implementation    : ", address(assetFactoryImplementation));

        // Deploy the Asset Factory Proxy contract
        bytes memory data = abi.encodeWithSelector(assetFactoryImplementation.initialize.selector);
        ERC1967Proxy assetFactoryProxy = new ERC1967Proxy(address(assetFactoryImplementation), data);
        assetFactory = AssetFactory(address(assetFactoryProxy));
        console.log("Asset Factory                   : ", address(assetFactory));

        // Deploy the CorkConfig contract
        config = new CorkConfig();
        console.log("Cork Config                     : ", address(config));

        // Deploy the FlashSwapRouter implementation (logic) contract
        RouterState routerImplementation = new RouterState();
        console.log("Flashswap Router Implementation : ", address(routerImplementation));

        // Deploy the FlashSwapRouter Proxy contract
        data = abi.encodeWithSelector(routerImplementation.initialize.selector);
        ERC1967Proxy routerProxy = new ERC1967Proxy(address(routerImplementation), data);
        flashswapRouter = RouterState(address(routerProxy));
        console.log("Flashswap Router Proxy          : ", address(flashswapRouter));

        // Deploy the UniswapV2Factory contract
        address _factory = deployCode(v2FactoryArtifact, abi.encode(msg.sender, address(flashswapRouter)));
        factory = IUniswapV2Factory(_factory);
        console.log("Univ2 Factory                   : ", _factory);

        // Deploy the UniswapV2Router contract
        address _router = deployCode(v2RouterArtifact, abi.encode(_factory, address(weth), address(flashswapRouter)));
        univ2Router = IUniswapV2Router02(_router);
        console.log("Univ2 Router                    : ", _router);

        // Deploy the ModuleCore contract
        moduleCore = new ModuleCore(
            address(assetFactory), _factory, address(flashswapRouter), _router, address(config), base_redemption_fee
        );
        console.log("Module Core                     : ", address(moduleCore));

        // Transfer Ownership to moduleCore
        assetFactory.transferOwnership(address(moduleCore));
        flashswapRouter.transferOwnership(address(moduleCore));
        console.log("Transferred ownerships to Modulecore");
        vm.stopBroadcast();
    }
}
