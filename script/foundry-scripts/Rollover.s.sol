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

    CorkConfig config = CorkConfig(0x190305d34e061F7739CbfaD9fC8e5Ece94C86467);
    RouterState flashSwapRouter = RouterState(0x8547ac5A696bEB301D5239CdE9F3894B106476C9);
    ModuleCore moduleCore = ModuleCore(0xF6a5b7319DfBc84EB94872478be98462aA9Aab99);

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
