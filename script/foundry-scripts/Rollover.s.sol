pragma solidity 0.8.24;

import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
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
    address ceth = 0x93D16d90490d812ca6fBFD29E8eF3B31495d257D;

    Assets mlETH = Assets(ceth, 0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6, 4 days, 1 ether);
    Assets lbETH = Assets(ceth, 0xF24177162B1604e56EB338dd9775d75CC79DaC2B, 4 days, 0.5 ether);
    Assets bsETH = Assets(ceth, 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9, 4 days, 0);
    Assets wamuETH = Assets(ceth, 0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B, 6 days, 0.25 ether);

    CorkConfig config = CorkConfig(0x8c996E7f76fB033cDb83CE1de7c3A134e17Cc227);
    RouterState flashSwapRouter = RouterState(0x6629e017455CB886669e725AF1BC826b65cB6f24);
    ModuleCore moduleCore = ModuleCore(0xe56565c208d0a8Ca28FB632aD7F6518f273B8B9f);

    // 6% decay discount rate
    uint256 internal constant DEFAULT_DECAY_DISCOUNT_RATE = 6 ether;

    uint256 internal constant DEFAULT_EXCHANGE_RATE = 1 ether;

    uint256 public pk = vm.envUint("PRIVATE_KEY");

    // TODO(confirm with rob): roughly 22 hours
    uint256 DEFAULT_ROLLOVER_PERIOD = 6600;

    function issueNewDs(Assets memory asset) internal {
        string memory tokenName = CST(asset.peggedAsset).name();
        string memory tokenSymbol = CST(asset.peggedAsset).symbol();

        console.log("--------------- %s (%s) ---------------", tokenName, tokenSymbol);

        Id id = PairLibrary.toId(PairLibrary.initalize(asset.peggedAsset, asset.redemptionAsset));

        uint256 currentHPA = flashSwapRouter.getCurrentCumulativeHPA(id);

        console.log("Current HPA  : ", currentHPA);

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
            block.timestamp + asset.expiryInterval,
            DEFAULT_EXCHANGE_RATE,
            asset.repruchaseFee,
            DEFAULT_DECAY_DISCOUNT_RATE,
            DEFAULT_ROLLOVER_PERIOD
        );

        uint256 afterDsId = moduleCore.lastDsId(id);
        assert(afterDsId == dsId + 1);

        console.log("ISSUED A NEW DS --");
        console.log("new DS with ID     : ", afterDsId);
        (ct,) = moduleCore.swapAsset(id, afterDsId);
        expiry = Asset(ct).expiry();

        console.log("New DS Expiry      : ", expiry);

        currentHPA = flashSwapRouter.getCurrentEffectiveHPA(id);

        console.log("Current HPA        : ", currentHPA);
    }

    function run() public {
        vm.startBroadcast(pk);
        Assets[4] memory assets = [bsETH, lbETH, mlETH, wamuETH];

        for (uint256 i = 0; i < assets.length; i++) {
            issueNewDs(assets[i]);
        }
        vm.stopBroadcast();
    }
}
