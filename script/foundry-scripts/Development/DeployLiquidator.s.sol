pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Liquidator} from "../../../contracts/core/liquidators/Liquidator.sol";
import {Utils} from "../Utils/Utils.s.sol"; // Import the Utils contract
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployLiquidatorScript is Script {
    Liquidator public liquidator;

    address deployer = 0x036febB27d1da9BFF69600De3C9E5b6cd6A7d275;
    address weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address usdc = 0xbe72E441BF55620febc26715db68d3494213D8Cb;
    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    uint256 public raAmount = 10000000000000000;
    uint256 public paAmount = 4550200000000000000;

    // TODO : Add the hookTrampoline address
    address hookTrampoline = vm.addr(pk);

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        liquidator = new Liquidator(deployer, hookTrampoline, settlementContract);

        console.log("liquidator Contract: ", address(liquidator));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        ERC20 WETH = ERC20(weth);
        WETH.approve(address(liquidator), raAmount);

        console.log("order request sent");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");
        vm.stopBroadcast();
    }
}
