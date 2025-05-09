// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CtOracle} from "../../../../contracts/core/oracles/CTOracle.sol";
import {CTOracleFactory} from "../../../../contracts/core/oracles/CTOracleFactory.sol";
import {ICTOracleFactory} from "../../../../contracts/interfaces/ICTOracleFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CTOracleTest is Test {
    CtOracle public oracle;
    CTOracleFactory public factory;

    address public factoryOwner;
    address public user;
    address public ctToken;

    function setUp() public {
        factoryOwner = makeAddr("factoryOwner");
        user = makeAddr("user");
        ctToken = makeAddr("ctToken");

        vm.startPrank(factoryOwner);
        // Deploy factory implementation
        CTOracleFactory implementation = new CTOracleFactory();

        // Deploy proxy with implementation
        bytes memory initData = abi.encodeWithSelector(implementation.initialize.selector, factoryOwner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        factory = CTOracleFactory(address(proxy));
        vm.stopPrank();

        vm.startPrank(user);
        // Create an oracle using the factory
        address oracleAddress = factory.createCTOracle(ctToken);
        oracle = CtOracle(oracleAddress);
        vm.stopPrank();
    }
}
