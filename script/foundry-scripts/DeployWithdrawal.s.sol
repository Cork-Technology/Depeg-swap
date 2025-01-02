pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {UniswapPriceReader} from "../../contracts/readers/PriceReader.sol";
import {Utils} from "./Utils/Utils.s.sol"; // Import the Utils contract
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {Withdrawal} from "../../contracts/core/Withdrawal.sol";

contract DeployWithdrawalScript is Script {
    CorkConfig public config;
    Withdrawal public withdrawal;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address moduleCore = 0xc5f00EE3e3499e1b211d1224d059B8149cD2972D;
    address configAdd = 0x7DD402c84fd951Dbef2Ef4459F67dFe8a4128f21;
    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        withdrawal = new Withdrawal(moduleCore);
        console.log("Withdrawal contracts : ", address(withdrawal));

        config = CorkConfig(configAdd);
        config.setWithdrawalContract(address(withdrawal));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");
        vm.stopBroadcast();
    }
}
