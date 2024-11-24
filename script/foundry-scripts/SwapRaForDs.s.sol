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
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address deployer = 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9;
    address public cUSD = 0xEEeA08E6F6F5abC28c821Ffe2035326C6Bfd2017;

    address bsETH = 0x0BAbf92b3e4fd64C26e1F6A05B59a7e0e0708378;
    uint256 bsETHexpiry = 302400;

    address wamuETH = 0xd9682A7CE1C48f1de323E9b27A5D0ff0bAA24254;
    uint256 wamuETHexpiry = 302400;

    address mlETH = 0x98524CaB765Cb0De83F71871c56dc67C202e166d;
    uint256 mlETHexpiry = 86400;

    address fedUSD = 0xd8d134BEc26f7ebdAdC2508a403bf04bBC33fc7b;
    uint256 fedUSDexpiry = 302400;

    address svbUSD = 0x7AE4c173d473218b59bF8A1479BFC706F28C635b;
    uint256 svbUSDexpiry = 302400;

    address omgUSD = 0x182733031965686043d5196207BeEE1dadEde818;
    uint256 omgUSDexpiry = 43200;

    CETH cETH;

    uint256 swapAmt = 10000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        moduleCore = ModuleCore(0x8445a4caD9F5a991E668427dC96A0a6b80ca629b);
        routerState = RouterState(0xA4Ad536e6AE5D8B26b8AD079046dff60bAC9abad);
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
        routerState.swapRaforDs(reserveId, 1, swapAmt, 0, deployer, bytes(""), 0, params);
        console.log("Swap RA for DS");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
