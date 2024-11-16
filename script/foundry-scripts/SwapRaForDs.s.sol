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
    address public cUSD = 0x8cdd2A328F36601A559c321F0eA224Cc55d9EBAa;

    address bsETH = 0x71710AcACeD2b5Fb608a1371137CC1becFf391E0;
    uint256 bsETHexpiry = 302400;

    address wamuETH = 0x212542457f2F50Ab04e74187cE46b79A8B330567;
    uint256 wamuETHexpiry = 302400;

    address mlETH = 0xc63b0e46FDA3be5c14719257A3EC235499Ca4D33;
    uint256 mlETHexpiry = 86400;

    address fedUSD = 0x618134155a3aB48003EC137FF1984f79BaB20028;
    uint256 fedUSDexpiry = 302400;

    address svbUSD = 0x80bA1d3DF59c62f3C469477C625F4F1D9a1532E6;
    uint256 svbUSDexpiry = 302400;

    address omgUSD = 0xD8CEF48A9dc21FFe2ef09A7BD247e28e11b5B754;
    uint256 omgUSDexpiry = 43200;

    CETH cETH;

    uint256 swapAmt = 10000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        moduleCore = ModuleCore(0x0e5212A25DDbf4CBEa390199b62C249aBf3637fF);
        routerState = RouterState(0x7ff313778Ca50e1cB5BD8a3B1408D931F14FEce4);
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
        IDsFlashSwapCore.BuyAprroxParams memory params = IDsFlashSwapCore.BuyAprroxParams(256, 0.01 ether, 1 gwei);
        routerState.swapRaforDs(reserveId, 1, swapAmt, 0, deployer, bytes(""), 0, params);
        console.log("Swap RA for DS");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
