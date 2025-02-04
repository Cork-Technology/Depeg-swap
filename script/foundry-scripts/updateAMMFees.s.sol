// pragma solidity ^0.8.24;

// import {Script, console} from "forge-std/Script.sol";
// import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
// import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
// import {CETH} from "../../contracts/tokens/CETH.sol";
// import {CST} from "../../contracts/tokens/CST.sol";
// import {Id, PairLibrary} from "../../contracts/libraries/Pair.sol";
// import {IDsFlashSwapCore} from "../../contracts/interfaces/IDsFlashSwapRouter.sol";
// import {CorkConfig} from "../../contracts/core/CorkConfig.sol";

// struct Assets {
//     address redemptionAsset;
//     address peggedAsset;
//     uint256 expiryInterval;
//     uint256 repruchaseFee;
//     uint256 ammHookFees;
// }

// contract AMMFeesScript is Script {
//     ModuleCore public moduleCore;
//     RouterState public routerState;
//     CorkConfig public config;

//     bool public isProd = vm.envBool("PRODUCTION");
//     uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
//     uint256 public pk = vm.envUint("PRIVATE_KEY");
//     address deployer = 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9;
//     address ceth = 0xbcD4B73511328Fd44416ce7189eb64F063DA5F41;
//     address cusd = 0xA69b095360F2DD024Ff0571bA12D9CA6823D2C0b;
//     address bsETHAdd = 0xaF4acbB6e9E7C13D8787a60C199462Bc3095Cad7;
//     address wamuETHAdd = 0xC9eF4a21d0261544b10CC5fC9096c3597daaA29d;
//     address mlETHAdd = 0x2B56646D79375102b5aaaf3c228EE90DE2913d5E;
//     address svbUSDAdd = 0xBF578784a7aFaffE5b63C60Ed051E55871B7E114;
//     address fedUSDAdd = 0xa4A181100F7ef4448d0d34Fd0B6Dc17ecE5C1442;
//     address omgUSDAdd = 0x34f49a5b81B61E91257460E0C6c168Ccee86a4b1;

//     uint256 wamuETHExpiry = 3.5 days;
//     uint256 bsETHExpiry = 3.5 days;
//     uint256 mlETHExpiry = 1 days;
//     uint256 svbUSDExpiry = 3.5 days;
//     uint256 fedUSDExpiry = 3.5 days;
//     uint256 omgUSDExpiry = 0.5 days;

//     Assets mlETH = Assets(bsETHAdd, mlETHAdd, mlETHExpiry, 0.75 ether, 0.3 ether);
//     Assets bsETH = Assets(wamuETHAdd, bsETHAdd, bsETHExpiry, 0.75 ether, 0.3 ether);
//     Assets wamuETH = Assets(ceth, wamuETHAdd, wamuETHExpiry, 0.75 ether, 0.15 ether);
//     Assets svbUSD = Assets(fedUSDAdd, svbUSDAdd, svbUSDExpiry, 0.75 ether, 0.3 ether);
//     Assets fedUSD = Assets(cusd, fedUSDAdd, fedUSDExpiry, 0.75 ether, 0.15 ether);
//     Assets omgUSD = Assets(svbUSDAdd, omgUSDAdd, omgUSDExpiry, 0.75 ether, 0.3 ether);

//     function setUp() public {}

//     function run() public {
//         vm.startBroadcast(pk);

//         moduleCore = ModuleCore(0xc5f00EE3e3499e1b211d1224d059B8149cD2972D);
//         routerState = RouterState(0xC89c5b91d6389FDDa8A0Ee29dc2eFC7330Ee42A1);
//         config = CorkConfig(0x7DD402c84fd951Dbef2Ef4459F67dFe8a4128f21);

//         console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

//         Assets[6] memory assets = [mlETH, bsETH, wamuETH, svbUSD, fedUSD, omgUSD];
//         // Assets[1] memory assets = [wamuETH];

//         for (uint256 i = 0; i < assets.length; i++) {
//             updateFees(assets[i]);
//         }

//         console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
//         vm.stopBroadcast();
//     }

//     function updateFees(Assets memory asset) public {
//         address exchangeRateProvider = address(config.defaultExchangeRateProvider());
//         Id id = moduleCore.getId(asset.peggedAsset, asset.redemptionAsset, asset.expiryInterval, exchangeRateProvider);
//         uint256 dsId = moduleCore.lastDsId(id);
//         (address ctToken,) = moduleCore.swapAsset(id, dsId);
//         console.log("RA token: ", asset.redemptionAsset);
//         console.log("CT token: ", ctToken);
//         console.log("dsId: ", dsId);
//         config.updateAmmBaseFeePercentage(id, asset.ammHookFees);
//         console.log("Fees updated");
//         console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
//     }
// }
