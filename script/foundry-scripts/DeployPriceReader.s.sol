pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {UniswapPriceReader} from "../../contracts/readers/PriceReader.sol";
import {Utils} from "./Utils/Utils.s.sol"; // Import the Utils contract

contract DeployPriceReaderScript is Script {
    UniswapPriceReader public priceReader;

    uint256 public pk = vm.envUint("PRIVATE_KEY");

    address uniswapV2FactorySepolia = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
    address uniswapV2RouterSepolia = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

    address ceth = 0x0000000237805496906796B1e767640a804576DF;
    address cusd = 0x1111111A3Ae9c9b133Ea86BdDa837E7E796450EA;
    address bsETH = 0x33333335a697843FDd47D599680Ccb91837F59aF;
    address wamuETH = 0x22222228802B45325E0b8D0152C633449Ab06913;
    address mlETH = 0x44444447386435500C5a06B167269f42FA4ae8d4;
    address svbUSD = 0x5555555eBBf30a4b084078319Da2348fD7B9e470;
    address fedUSD = 0x666666685C211074C1b0cFed7e43E1e7D8749E43;
    address omgUSD = 0x7777777707136263F82775e7ED0Fc99Bbe6f5eB0;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        priceReader = new UniswapPriceReader(uniswapV2FactorySepolia, uniswapV2RouterSepolia);
        console.log("Price Reader Contract: ", address(priceReader));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cETH price           : ", Utils.formatEther(priceReader.getTokenPrice(cETH, wamuETH)), " wamuETH");
        console.log("wamuETH price        : ", Utils.formatEther(priceReader.getTokenPrice(wamuETH, cETH)), " cETH");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cETH price           : ", Utils.formatEther(priceReader.getTokenPrice(cETH, bsETH)), " bsETH");
        console.log("bsETH price          : ", Utils.formatEther(priceReader.getTokenPrice(bsETH, cETH)), " cETH");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cETH price           : ", Utils.formatEther(priceReader.getTokenPrice(cETH, mlETH)), " mlETH");
        console.log("mlETH price          : ", Utils.formatEther(priceReader.getTokenPrice(mlETH, cETH)), " cETH");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cUSD price           : ", Utils.formatEther(priceReader.getTokenPrice(cUSD, fedUSD)), " fedUSD");
        console.log("fedUSD price          : ", Utils.formatEther(priceReader.getTokenPrice(fedUSD, cUSD)), " cUSD");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cUSD price           : ", Utils.formatEther(priceReader.getTokenPrice(cUSD, svbUSD)), " svbUSD");
        console.log("svbUSD price          : ", Utils.formatEther(priceReader.getTokenPrice(svbUSD, cUSD)), " cUSD");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");

        console.log("cUSD price           : ", Utils.formatEther(priceReader.getTokenPrice(cUSD, omgUSD)), " omgUSD");
        console.log("omgUSD price          : ", Utils.formatEther(priceReader.getTokenPrice(omgUSD, cUSD)), " cUSD");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-");
        vm.stopBroadcast();
    }
}
