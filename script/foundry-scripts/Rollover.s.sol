pragma solidity ^0.8.24;

import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./../../contracts/libraries/DsSwapperMathLib.sol";
import "forge-std/console.sol";
import "./../../contracts/libraries/Pair.sol";
import "./../../contracts/core/assets/Asset.sol";

struct Assets {
    address redemptionAsset;
    address peggedAsset;
    uint256 expiryInterval;
    uint256 repruchaseFee;
}

contract RolloverScript is Script {
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

    CorkConfig config = CorkConfig(0xCA98b865821850dea56ab65F3f6C90E78D550015);
    RouterState flashSwapRouter = RouterState(0x96EE05bA5F2F2D3b4a44f174e5Df3bba1B9C0D17);
    ModuleCore moduleCore = ModuleCore(0x3390573A8Cd1aB9CFaE5e1720e4e7867Ed074a38);

    // 6% decay discount rate
    uint256 internal constant DEFAULT_DECAY_DISCOUNT_RATE = 6 ether;

    uint256 internal constant DEFAULT_EXCHANGE_RATE = 1 ether;

    uint256 public pk = vm.envUint("PRIVATE_KEY");

    // roughly 6 hours
    uint256 DEFAULT_ROLLOVER_PERIOD = 1800;

    function issueNewDs(Assets memory asset) internal {
        string memory tokenName = CST(asset.peggedAsset).name();
        string memory tokenSymbol = CST(asset.peggedAsset).symbol();

        console.log("--------------- %s (%s) ---------------", tokenName, tokenSymbol);

        Id id = PairLibrary.toId(PairLibrary.initalize(asset.peggedAsset, asset.redemptionAsset, asset.expiryInterval));

        uint256 currentHPA = flashSwapRouter.getCurrentCumulativeHIYA(id);

        console.log("Current HIYA  : ", currentHPA);

        uint256 dsId = moduleCore.lastDsId(id);

        console.log("Current DS ID      : ", dsId);

        (address ct,) = moduleCore.swapAsset(id, dsId);
        uint256 expiry = Asset(ct).expiry();
        uint256 currentTime = block.timestamp;

        console.log("Current Expiry     : ", expiry);
        console.log("Current Time       : ", currentTime);

        // for formatting
        console.log("");

        // skip if not expired
        if (expiry > currentTime) {
            console.log("DS is not expired, skipping...");
            return;
        }

        console.log("Issuing new DS...");
        config.issueNewDs(
            id,
            DEFAULT_EXCHANGE_RATE,
            asset.repruchaseFee,
            DEFAULT_DECAY_DISCOUNT_RATE,
            DEFAULT_ROLLOVER_PERIOD,
            block.timestamp + 20 minutes
        );

        uint256 afterDsId = moduleCore.lastDsId(id);
        assert(afterDsId == dsId + 1);

        console.log("ISSUED A NEW DS --");
        console.log("new DS with ID     : ", afterDsId);
        (ct,) = moduleCore.swapAsset(id, afterDsId);
        expiry = Asset(ct).expiry();

        console.log("New DS Expiry      : ", expiry);

        currentHPA = flashSwapRouter.getCurrentEffectiveHIYA(id);

        console.log("Current HIYA        : ", currentHPA);
    }

    function run() public {
        vm.startBroadcast(pk);
        Assets[6] memory assets = [mlETH, bsETH, wamuETH, svbUSD, fedUSD, omgUSD];
        // Assets[1] memory assets = [mlETH];

        for (uint256 i = 0; i < assets.length; i++) {
            issueNewDs(assets[i]);
        }
        vm.stopBroadcast();
    }
}
