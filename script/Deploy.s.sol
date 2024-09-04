// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CorkConfig} from "../contracts/core/CorkConfig.sol";

contract DeployScript is Script {
    CorkConfig public config;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        config = new CorkConfig();

        vm.stopBroadcast();
    }
}
