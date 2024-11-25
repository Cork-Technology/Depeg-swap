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

    CorkConfig config = CorkConfig(0x2039a7923b275efB3b211e58720F5AD77a3a4cCC);
    RouterState flashSwapRouter = RouterState(0x6B7406Ab9fa8d26B8E85060977e6737E0dF32b83);
    ModuleCore moduleCore = ModuleCore(0xC675522e3047b417F7CB5dD2d7Ef4c48b318DadF);

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
