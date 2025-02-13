// script/UpgradeUUPS.s.sol
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {FlashSwapRouter} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeUUPSScript is Script {
    function run() external {
        // Load the private key to deploy and upgrade
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Begin broadcasting (i.e., sending transactions)
        vm.startBroadcast(deployerPrivateKey);
        address user = vm.addr(deployerPrivateKey);
        address flashSwapProxyAddress = 0x8547ac5A696bEB301D5239CdE9F3894B106476C9;

        FlashSwapRouter(flashSwapProxyAddress).grantRole(keccak256("CONFIG"), address(user));

        // Step 1: Deploy the new implementation contract (FlashSwapRouter)
        FlashSwapRouter newImplementation = new FlashSwapRouter();
        console.log("New implementation deployed at:", address(newImplementation));

        // Step 2: Upgrade the proxy contract to use the new implementation
        (bool success,) = flashSwapProxyAddress.call(
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(newImplementation), "")
        );
        require(success, "Upgrade failed");

        console.log("Proxy upgraded to new implementation!");
        vm.stopBroadcast();
    }
}
