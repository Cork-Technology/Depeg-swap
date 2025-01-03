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
    address ceth = 0xbcD4B73511328Fd44416ce7189eb64F063DA5F41;
    address cusd = 0xA69b095360F2DD024Ff0571bA12D9CA6823D2C0b;
    address bsETHAdd = 0xaF4acbB6e9E7C13D8787a60C199462Bc3095Cad7;
    address wamuETHAdd = 0xC9eF4a21d0261544b10CC5fC9096c3597daaA29d;
    address mlETHAdd = 0x2B56646D79375102b5aaaf3c228EE90DE2913d5E;
    address svbUSDAdd = 0xBF578784a7aFaffE5b63C60Ed051E55871B7E114;
    address fedUSDAdd = 0xa4A181100F7ef4448d0d34Fd0B6Dc17ecE5C1442;
    address omgUSDAdd = 0x34f49a5b81B61E91257460E0C6c168Ccee86a4b1;

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

    CorkConfig config = CorkConfig(0x7DD402c84fd951Dbef2Ef4459F67dFe8a4128f21);
    RouterState flashSwapRouter = RouterState(0xC89c5b91d6389FDDa8A0Ee29dc2eFC7330Ee42A1);
    ModuleCore moduleCore = ModuleCore(0xc5f00EE3e3499e1b211d1224d059B8149cD2972D);

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

        for (uint256 i = 0; i < assets.length; i++) {
            issueNewDs(assets[i]);
        }        
        vm.stopBroadcast();
    }
}
