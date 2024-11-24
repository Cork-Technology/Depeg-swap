pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {CorkHook, LiquidityToken, Hooks} from "Cork-Hook/CorkHook.sol";

contract DeployUniV4Script is Script {
    PoolManager public poolManager;
    LiquidityToken public liquidityToken;

    uint256 public pk = vm.envUint("PRIVATE_KEY");

    function run() public {
        vm.startBroadcast(pk);
        // deploy hook
        poolManager = new PoolManager();
        console.log("Pool Manager                    : ", address(poolManager));
        liquidityToken = new LiquidityToken();
        console.log("Liquidity Token                 : ", address(liquidityToken));
    }
}
