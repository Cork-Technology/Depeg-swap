pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RouterState} from "contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "contracts/core/ModuleCore.sol";

contract UpgradeContractScript is Script {
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    address public flashswapRouterProxy = 0x14B04A7ff48099DB786c5d63b199AccD108E2c90;
    address public moduleCoreProxy = 0xc6c5880d3a6097Cb7905986fEAFbC30B533fA39D;

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the FlashSwapRouter implementation (logic) contract
        RouterState routerImplementation = new RouterState();
        console.log("New Flashswap Router Implementation : ", address(routerImplementation));

        // Upgrade the FlashSwapRouter Proxy contract
        flashswapRouter = RouterState(flashswapRouterProxy);
        flashswapRouter.upgradeToAndCall(address(routerImplementation), bytes(""));
        console.log("Flashswap Router Proxy Upgraded     : ", address(flashswapRouter));

        // Deploy the ModuleCore implementation contract
        ModuleCore moduleCoreImplementation = new ModuleCore();
        console.log("New ModuleCore Implementation : ", address(moduleCoreImplementation));

        // Upgrade the ModuleCore Proxy contract
        moduleCore = ModuleCore(moduleCoreProxy);
        moduleCore.upgradeToAndCall(address(moduleCoreImplementation), bytes(""));
        console.log("ModuleCore Proxy Upgraded           : ", address(moduleCore));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
