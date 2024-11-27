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
    address ceth = 0x11649B3aEc3D4Cd35D0727D786c234329B756fd9;
    address cusd = 0x4c82BdeDD41bf0284fd6BCa1b6A317fEF6A6d237;
    address bsETHAdd = 0x2019e2E0D0DE78b65ce698056EAE468192b40daC;
    address wamuETHAdd = 0x81EcEa063eB1E477365bd6c0AE7E1d1f3d84442E;
    address mlETHAdd = 0xD1813fD95E557d273E8009db91C6BC412F56eE56;
    address svbUSDAdd = 0xeD273d746bC1CefA9467ea5e81e9cd22eaC27397;
    address fedUSDAdd = 0xEBdc16512a8c79c39EB27cc27e387039AF573f82;
    address omgUSDAdd = 0x42B025047A12c403803805195230C257D2170Bb1;

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
        vm.pauseGasMetering();

        moduleCore = ModuleCore(0x3390573A8Cd1aB9CFaE5e1720e4e7867Ed074a38);
        routerState = RouterState(0x96EE05bA5F2F2D3b4a44f174e5Df3bba1B9C0D17);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        Assets[6] memory assets = [mlETH, bsETH, wamuETH, svbUSD, fedUSD, omgUSD];
        // Assets[3] memory assets = [mlETH, bsETH, omgUSD];
        // Assets[1] memory assets = [fedUSD];

        for (uint256 i = 0; i < assets.length; i++) {

            for (uint256 j = 0; j < 100; j++) {
                console.log("Swapping iteration: ", j);
                swapRaForDs(assets[i], 0.01 ether);
            }
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
            IDsFlashSwapCore.BuyAprroxParams(108, 108, 1 ether, 1 gwei, 1 gwei);
        routerState.swapRaforDs(reserveId, dsId, swapAmt, 0, params);
        console.log("Swap RA for DS");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
