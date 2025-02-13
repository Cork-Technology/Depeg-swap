// pragma solidity 0.8.26;

// import {CorkHook} from "Cork-Hook/CorkHook.sol";
// import {Script, console} from "forge-std/Script.sol";
// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
// import {FlashSwapRouter} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
// import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
// import {CETH} from "../../contracts/tokens/CETH.sol";
// import {CUSD} from "../../contracts/tokens/CUSD.sol";
// import {CST} from "../../contracts/tokens/CST.sol";
// import {Id} from "../../contracts/libraries/Pair.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract SwapScript is Script {
//     CorkHook public hook;
//     CorkConfig public config;
//     FlashSwapRouter public flashswapRouter;
//     ModuleCore public moduleCore;

//     bool public isProd = vm.envBool("PRODUCTION");
//     uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
//     address public ceth = vm.envAddress("WETH");
//     address public cusd = vm.envAddress("CUSD");
//     uint256 public pk = vm.envUint("PRIVATE_KEY");
//     address sender = vm.addr(pk);

//     address internal constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

//     address wamuETH = 0xC9eF4a21d0261544b10CC5fC9096c3597daaA29d;
//     address bsETH = 0xaF4acbB6e9E7C13D8787a60C199462Bc3095Cad7;
//     address mlETH = 0x2B56646D79375102b5aaaf3c228EE90DE2913d5E;
//     address svbUSD = 0xBF578784a7aFaffE5b63C60Ed051E55871B7E114;
//     address fedUSD = 0xa4A181100F7ef4448d0d34Fd0B6Dc17ecE5C1442;
//     address omgUSD = 0x34f49a5b81B61E91257460E0C6c168Ccee86a4b1;

//     uint256 wamuETHExpiry = 3.5 days;
//     uint256 bsETHExpiry = 3.5 days;
//     uint256 mlETHExpiry = 1 days;
//     uint256 svbUSDExpiry = 3.5 days;
//     uint256 fedUSDExpiry = 3.5 days;
//     uint256 omgUSDExpiry = 0.5 days;

//     CETH cETH = CETH(ceth);
//     CUSD cUSD = CUSD(cusd);

//     function run() public {
//         vm.startBroadcast(pk);
//         cETH = CETH(ceth);
//         cUSD = CUSD(cusd);

//         moduleCore = ModuleCore(0xc5f00EE3e3499e1b211d1224d059B8149cD2972D);
//         hook = CorkHook(0xAe6a82F0C6D3d99757c5C4581AE8b1e6116A6a88);

//         depositToLv(wamuETH, ceth, wamuETHExpiry, 200 ether);
//         depositToLv(bsETH, wamuETH, bsETHExpiry, 200 ether);
//         depositToLv(mlETH, bsETH, mlETHExpiry, 200 ether);
//         depositToLv(svbUSD, fedUSD, svbUSDExpiry, 200 ether);
//         depositToLv(fedUSD, cusd, fedUSDExpiry, 200 ether);
//         depositToLv(omgUSD, svbUSD, omgUSDExpiry, 200 ether);

//         // swapRaCtTokens(wamuETH, ceth, wamuETHExpiry, 200 ether);
//         // swapRaCtTokens(bsETH, wamuETH, bsETHExpiry, 200 ether);
//         // swapRaCtTokens(mlETH, bsETH, mlETHExpiry, 200 ether);
//         // swapRaCtTokens(svbUSD, fedUSD, wamuETHExpiry, 200 ether);
//         // swapRaCtTokens(fedUSD, cusd, bsETHExpiry, 200 ether);
//         // swapRaCtTokens(omgUSD, svbUSD, mlETHExpiry, 200 ether);
//         console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
//         vm.stopBroadcast();
//     }

//     function depositToLv(
//         address paToken,
//         address raToken,
//         uint256 expiryPeriod,
//         uint256 depositLVAmt
//     ) public {
//         address exchangeRateProvider = address(config.defaultExchangeRateProvider());
//         Id id = moduleCore.getId(paToken, raToken, expiryPeriod, exchangeRateProvider);
//         CETH(raToken).approve(address(moduleCore), depositLVAmt);
//         moduleCore.depositLv(id, depositLVAmt, 0, 0);
//         console.log("LV Deposited");
//         console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
//     }

//     // function swapRaCtTokens(address paToken, address raToken, uint256 expiryPeriod, uint256 amount) public {
//     //     Id id = moduleCore.getId(paToken, raToken, expiryPeriod);
//     //     uint256 dsId = moduleCore.lastDsId(id);
//     //     (address ctToken,) = moduleCore.swapAsset(id, dsId);

//     //     CETH(raToken).approve(address(moduleCore), amount);
//     //     moduleCore.depositPsm(id, amount);

//     //     CETH(raToken).approve(address(hook), amount);
//     //     IERC20(ctToken).approve(address(hook), amount);
//     //     hook.swap(raToken, ctToken, amount, 0, bytes(""));
//     //     console.log("Swapped RA with CT");

//     //     CETH(raToken).approve(address(hook), amount);
//     //     IERC20(ctToken).approve(address(hook), amount);
//     //     hook.swap(ctToken, raToken, amount, 0, bytes(""));
//     //     console.log("Swapped CT with RA");
//     // }
// }
