pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Funder} from "../../../contracts/tc_utils/Funder.sol";

contract DeployFunderScript is Script {
    Funder public funder;

    address public ceth = vm.envAddress("WETH");
    address public cusd = vm.envAddress("CUSD");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        funder = new Funder(ceth, cusd);
        console.log("Funder Contract                           : ", address(funder));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
