pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {UniswapPriceReader} from "../../contracts/readers/PriceReader.sol";
import {Utils} from "./Utils/Utils.s.sol"; // Import the Utils contract

contract DeployPriceReaderScript is Script {
    UniswapPriceReader public priceReader;

    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    address cETH = 0x93D16d90490d812ca6fBFD29E8eF3B31495d257D;
    address bsETH = 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9;
    address lbETH = 0xF24177162B1604e56EB338dd9775d75CC79DaC2B;
    address wamuETH = 0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B;
    address mlETH = 0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        priceReader = new UniswapPriceReader(
            0x8fD48F4ec9cB04540134c02f4dAa5f68585c3936, 0x363E8886E8FF30b6f6770712Cf4e758e2Bf3E353
        );
        console.log("Price Reader Contract: ", address(priceReader));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cETH price           : ", Utils.formatEther(priceReader.getTokenPrice(cETH, bsETH)), " bsETH");
        console.log("bsETH price          : ", Utils.formatEther(priceReader.getTokenPrice(bsETH, cETH)), " cETH");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cETH price           : ", Utils.formatEther(priceReader.getTokenPrice(cETH, lbETH)), " lbETH");
        console.log("lbETH price          : ", Utils.formatEther(priceReader.getTokenPrice(lbETH, cETH)), " cETH");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cETH price           : ", Utils.formatEther(priceReader.getTokenPrice(cETH, wamuETH)), " wamuETH");
        console.log("wamuETH price        : ", Utils.formatEther(priceReader.getTokenPrice(wamuETH, cETH)), " cETH");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cETH price           : ", Utils.formatEther(priceReader.getTokenPrice(cETH, mlETH)), " mlETH");
        console.log("mlETH price          : ", Utils.formatEther(priceReader.getTokenPrice(mlETH, cETH)), " cETH");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");
        vm.stopBroadcast();
    }
}
