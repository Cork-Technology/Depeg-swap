pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import "forge-std/Test.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id, PairLibrary} from "../../contracts/libraries/Pair.sol";
import {IDsFlashSwapCore} from "../../contracts/interfaces/IDsFlashSwapRouter.sol";

struct Assets {
    address redemptionAsset;
    address peggedAsset;
    uint256 expiryInterval;
    uint256 repruchaseFee;
}

contract SwapRAForDSScript is Test {
    ModuleCore public moduleCore;
    RouterState public routerState;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    uint256 pk = vm.envUint("PRIVATE_KEY");
    string  sepoliaUrl = vm.envString("SEPOLIA_URL");
    address user = vm.addr(pk);
    address deployer = 0x036febB27d1da9BFF69600De3C9E5b6cd6A7d275;
    address ceth = 0x0000000237805496906796B1e767640a804576DF;
    address cusd = 0x1111111A3Ae9c9b133Ea86BdDa837E7E796450EA;
    address bsETHAdd = 0x33333335a697843FDd47D599680Ccb91837F59aF;
    address wamuETHAdd = 0x22222228802B45325E0b8D0152C633449Ab06913;
    address mlETHAdd = 0x44444447386435500C5a06B167269f42FA4ae8d4;
    address svbUSDAdd = 0x5555555eBBf30a4b084078319Da2348fD7B9e470;
    address fedUSDAdd = 0x666666685C211074C1b0cFed7e43E1e7D8749E43;
    address omgUSDAdd = 0x7777777707136263F82775e7ED0Fc99Bbe6f5eB0;

    uint256 wamuETHExpiry = 3.5 days;
    uint256 bsETHExpiry = 3.5 days;
    uint256 mlETHExpiry = 1 days;
    uint256 svbUSDExpiry = 3.5 days;
    uint256 fedUSDExpiry = 3.5 days;
    uint256 omgUSDExpiry = 0.5 days;

    Assets mlETH = Assets(bsETHAdd, mlETHAdd, mlETHExpiry, 0.75 ether);
    Assets bsETH = Assets(wamuETHAdd, bsETHAdd, bsETHExpiry, 0.75 ether);
    Assets wamuETH = Assets(ceth, wamuETHAdd, wamuETHExpiry, 0.75 ether);
    Assets svbUSD = Assets(fedUSDAdd, svbUSDAdd, svbUSDExpiry, 0.75 ether);
    Assets fedUSD = Assets(cusd, fedUSDAdd, fedUSDExpiry, 0.75 ether);
    Assets omgUSD = Assets(svbUSDAdd, omgUSDAdd, omgUSDExpiry, 0.75 ether);

    function setUp() public {
        vm.createSelectFork(sepoliaUrl, 7258085);
    }

    function test_run() public {
        vm.startPrank(user);
        vm.pauseGasMetering();

        moduleCore = ModuleCore(0xF6a5b7319DfBc84EB94872478be98462aA9Aab99);
        routerState = RouterState(0x8547ac5A696bEB301D5239CdE9F3894B106476C9);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Assets[6] memory assets = [mlETH, bsETH, wamuETH, svbUSD, fedUSD, omgUSD];
        // Assets[3] memory assets = [mlETH, bsETH, omgUSD];
        Assets[1] memory assets = [mlETH];

        for (uint256 i = 0; i < assets.length; i++) {
            swapRaForDs(assets[i], 1 ether);
        }

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }

    function swapRaForDs(Assets memory asset, uint256 swapAmt) public {
        Id reserveId = moduleCore.getId(asset.peggedAsset, asset.redemptionAsset, asset.expiryInterval);
        Id id = PairLibrary.toId(PairLibrary.initalize(asset.peggedAsset, asset.redemptionAsset, asset.expiryInterval));
        uint256 dsId = moduleCore.lastDsId(id);

        CETH(asset.redemptionAsset).approve(address(routerState), swapAmt);
        IDsFlashSwapCore.BuyAprroxParams memory params =
            IDsFlashSwapCore.BuyAprroxParams(108, 108, 1 ether, 1 gwei, 1 gwei, 0.01 ether);
        routerState.swapRaforDs(reserveId, dsId, swapAmt, 0, params);
        console.log("Swap RA for DS");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
