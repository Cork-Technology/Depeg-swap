pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Libraries} from "contracts/dummy/Libraries.sol";

contract DeployScript is Script {
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Deployer                        : ", deployer);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the Asset Factory implementation (logic) contract
        Libraries libraries = new Libraries();
        console.log("Libraries Deployed    : ", address(libraries));
        vm.stopBroadcast();
    }
}
