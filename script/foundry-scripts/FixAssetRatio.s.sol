pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FixAssetRatioScript is Script {
    bool public isProd = vm.envBool("PRODUCTION");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    uint256 public pk2 = vm.envUint("PRIVATE_KEY2");
    uint256 public pk3 = vm.envUint("PRIVATE_KEY3");

    address user1 = 0x8e6dd65c50b57fD5935788Dc24d3E954Cd8fc019;
    address user2 = 0xFFB6b6896D469798cE64136fd3129979411B5514;
    address user3 = 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9;

    address bsETH = 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9;
    address lbETH = 0xF24177162B1604e56EB338dd9775d75CC79DaC2B;
    address wamuETH = 0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B;
    address mlETH = 0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6;
@Zian pushed script FixAssetRatioScript crosscheck it... looking good to me
@rob confirm script output so i can make transaction 
    CETH cETH = CETH(ceth);

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk3);
        CST bsETHCST = CST(bsETH);
        console.log("total bsETH Supply                       : ", bsETHCST.totalSupply());
        console.log("cETH in bsETH Before                     : ", cETH.balanceOf(bsETH));
        bsETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total bsETH Supply                       : ", bsETHCST.totalSupply());
        console.log("cETH in bsETH After                      : ", cETH.balanceOf(bsETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        CST lbETHCST = CST(lbETH);
        console.log("total lbETH Supply                       : ", lbETHCST.totalSupply());
        console.log("cETH in lbETH Before                     : ", cETH.balanceOf(lbETH));
        lbETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total lbETH Supply                       : ", lbETHCST.totalSupply());
        console.log("cETH in lbETH After                      : ", cETH.balanceOf(lbETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        CST wamuETHCST = CST(wamuETH);
        console.log("total wamuETH Supply                       : ", wamuETHCST.totalSupply());
        console.log("cETH in wamuETH Before                     : ", cETH.balanceOf(wamuETH));
        wamuETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total wamuETH Supply                       : ", wamuETHCST.totalSupply());
        console.log("cETH in wamuETH After                      : ", cETH.balanceOf(wamuETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        CST mlETHCST = CST(mlETH);
        console.log("total mlETH Supply                       : ", mlETHCST.totalSupply());
        console.log("cETH in mlETH Before                     : ", cETH.balanceOf(mlETH));
        mlETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total mlETH Supply                       : ", mlETHCST.totalSupply());
        console.log("cETH in mlETH After                      : ", cETH.balanceOf(mlETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
