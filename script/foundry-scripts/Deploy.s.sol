pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";

contract DeployScript is Script {
    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the Asset Factory implementation (logic) contract
        AssetFactory assetFactoryImplementation = new AssetFactory();
        address moduleCore = address(0x1234567890123456789012345678901234567890);

        // Deploy the CorkConfig contract
        config = new CorkConfig();

        // Deploy the FlashSwapRouter implementation (logic) contract
        RouterState routerImplementation = new RouterState();
        address univ2Router = address(0x1234567890123456789012345678901234567890);

        // Deploy the Asset Factory Proxy contract
        bytes memory data = abi.encodeWithSelector(assetFactoryImplementation.initialize.selector, moduleCore);
        ERC1967Proxy assetFactoryProxy = new ERC1967Proxy(address(assetFactoryImplementation), data);

        // Deploy the FlashSwapRouter Proxy contract
        data = abi.encodeWithSelector(routerImplementation.initialize.selector, moduleCore, univ2Router);
        ERC1967Proxy routerProxy = new ERC1967Proxy(address(routerImplementation), data);

        assetFactory = AssetFactory(address(assetFactoryProxy));
        flashswapRouter = RouterState(address(routerProxy));
        vm.stopBroadcast();
    }
}
