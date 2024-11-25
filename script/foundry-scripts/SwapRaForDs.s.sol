pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";
import {IDsFlashSwapCore} from "../../contracts/interfaces/IDsFlashSwapRouter.sol";

contract SwapRAForDSScript is Script {
    ModuleCore public moduleCore;
    RouterState public routerState;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address deployer = 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9;
    address public ceth = 0x0905A6A8Ad90d747D7cc57c0c043D4Fbb01BAC4f;
    address public cUSD = 0xcb5F36D3697DcB218Cb2266b373D5d7AA2745157;

    address bsETH = 0x30806bb1685Cd68DFb68a4616003Acc238412aF2;
    uint256 bsETHexpiry = 302400;

    address wamuETH = 0x69C1AF6a0FEA0AcEc09C084bE81C26A525Ba0702;
    uint256 wamuETHexpiry = 302400;

    address mlETH = 0xEcF2D124EE25EA4eB4bB834229537DBDb38560fe;
    uint256 mlETHexpiry = 86400;

    address fedUSD = 0x218780f6Ad2D26A65AeE30C5F9624304C31EECd0;
    uint256 fedUSDexpiry = 302400;

    address svbUSD = 0x31d576311E302CeF0E3bA80644c23333fd113c8f;
    uint256 svbUSDexpiry = 302400;

    address omgUSD = 0x5F73549336B58d0a61345934D4878078b50743B2;
    uint256 omgUSDexpiry = 43200;

    CETH cETH;

    uint256 swapAmt = 10000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        moduleCore = ModuleCore(0xC675522e3047b417F7CB5dD2d7Ef4c48b318DadF);
        routerState = RouterState(0x6B7406Ab9fa8d26B8E85060977e6737E0dF32b83);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        swapRaForDs(wamuETH, ceth, 500 ether, wamuETHexpiry);
        swapRaForDs(bsETH, wamuETH, 500 ether, bsETHexpiry);
        swapRaForDs(mlETH, bsETH, 500 ether, mlETHexpiry);
        swapRaForDs(fedUSD, cUSD, 500 ether, fedUSDexpiry);
        swapRaForDs(svbUSD, fedUSD, 500 ether, svbUSDexpiry);
        swapRaForDs(omgUSD, svbUSD, 500 ether, omgUSDexpiry);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function swapRaForDs(address cst, address cETHToken, uint256 liquidityAmt, uint256 expiryPeriod) public {
        Id reserveId = moduleCore.getId(cst, cETHToken, expiryPeriod);
        CETH(cETHToken).approve(address(routerState), swapAmt);
        IDsFlashSwapCore.BuyAprroxParams memory params =
            IDsFlashSwapCore.BuyAprroxParams(256, 256, 0.01 ether, 1 gwei, 1 gwei);
        routerState.swapRaforDs(reserveId, 1, swapAmt, 0, params);
        console.log("Swap RA for DS");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
