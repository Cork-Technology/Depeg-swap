// script/UpgradeUUPS.s.sol
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./../../contracts/core/ModuleCore.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeUUPSScript is Script {
    function run() external {
        // Load the private key to deploy and upgrade
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Begin broadcasting (i.e., sending transactions)
        vm.startBroadcast(deployerPrivateKey);
        address moduleCoreProxyAddress = 0xe56565c208d0a8Ca28FB632aD7F6518f273B8B9f;

        // Step 1: Deploy the new implementation contract (RouterState)
        ModuleCore newImplementation = new ModuleCore();
        console.log("New implementation deployed at:", address(newImplementation));

        // Step 2: Upgrade the proxy contract to use the new implementation
        (bool success,) = moduleCoreProxyAddress.call(
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(newImplementation), "")
        );
        require(success, "Upgrade failed");

        console.log("Proxy upgraded to new implementation!");
        vm.stopBroadcast();
    }
}
