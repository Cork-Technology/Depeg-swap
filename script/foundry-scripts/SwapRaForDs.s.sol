pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
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

contract SwapRAForDSScript is Script {
    ModuleCore public moduleCore;
    RouterState public routerState;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address deployer = 0x036febB27d1da9BFF69600De3C9E5b6cd6A7d275;
    address ceth = 0x0905A6A8Ad90d747D7cc57c0c043D4Fbb01BAC4f;
    address cusd = 0xcb5F36D3697DcB218Cb2266b373D5d7AA2745157;
    address bsETHAdd = 0x30806bb1685Cd68DFb68a4616003Acc238412aF2;
    address wamuETHAdd = 0x69C1AF6a0FEA0AcEc09C084bE81C26A525Ba0702;
    address mlETHAdd = 0xEcF2D124EE25EA4eB4bB834229537DBDb38560fe;
    address svbUSDAdd = 0x31d576311E302CeF0E3bA80644c23333fd113c8f;
    address fedUSDAdd = 0x218780f6Ad2D26A65AeE30C5F9624304C31EECd0;
    address omgUSDAdd = 0x5F73549336B58d0a61345934D4878078b50743B2;

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

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        moduleCore = ModuleCore(0xC675522e3047b417F7CB5dD2d7Ef4c48b318DadF);
        routerState = RouterState(0x6B7406Ab9fa8d26B8E85060977e6737E0dF32b83);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Assets[6] memory assets = [mlETH, bsETH, wamuETH, svbUSD, fedUSD, omgUSD];
        Assets[1] memory assets = [omgUSD];

        for (uint256 i = 0; i < assets.length; i++) {
            swapRaForDs(assets[i], 0.1 ether);
        }

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function swapRaForDs(Assets memory asset, uint256 swapAmt) public {
        Id reserveId = moduleCore.getId(asset.peggedAsset, asset.redemptionAsset, asset.expiryInterval);
        Id id = PairLibrary.toId(PairLibrary.initalize(asset.peggedAsset, asset.redemptionAsset, asset.expiryInterval));
        uint256 dsId = moduleCore.lastDsId(id);

        CETH(asset.redemptionAsset).approve(address(routerState), swapAmt);
        IDsFlashSwapCore.BuyAprroxParams memory params =
            IDsFlashSwapCore.BuyAprroxParams(108, 108, 0.01 ether, 1 gwei, 1 gwei);
        routerState.swapRaforDs(reserveId, dsId, swapAmt, 0, params);
        console.log("Swap RA for DS");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
