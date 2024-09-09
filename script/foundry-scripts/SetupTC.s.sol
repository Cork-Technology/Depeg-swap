pragma solidity 0.8.24;

import {IUniswapV2Factory} from "uniswap-v2/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {DummyWETH} from "../../contracts/dummy/DummyWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Id} from "../../contracts/libraries/Pair.sol";

interface ICST {
    function deposit(uint256 amount) external;
}

contract SetupTCScript is Script {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public univ2Router;

    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;
    ICST public cst;
    IERC20 public cETH;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PRECENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    uint256 mintAmount = 1_000_000_000_000 ether;
    uint256 depositLVAmt = 5000 ether;
    uint256 liquidityAmt = 1_000_000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        address bsETH = 0xB926f1279e58AF494976D324CC38866018CCa892;
        address lbETH = 0xCa15c974445d7C8A0aA14Bd5E6b3aFd5F22D7D17;
        address wamuETH = 0xE7Df8d2654183E4C809803850A56829131ae77f6;
        address mlETH = 0x4Bc92B2E2066906e0b4C1E1D9d30f985375D9268;

        moduleCore = ModuleCore(0x1647873c50Ec462039d4Eb4Fbd7bdFD8835a1133);
        config = CorkConfig(0x90C95749f0018F0C790CB2e9a93a2cE34181AdDA);
        univ2Router = IUniswapV2Router02(0x733732F1C66f1973b90ca443022Cef2B287EFCB6);

        cETH = IERC20(ceth);

        // cst = ICST(bsETH);
        // cETH.approve(bsETH, mintAmount);
        // cst.deposit(mintAmount);

        // cst = ICST(lbETH);
        // cETH.approve(lbETH, mintAmount);
        // cst.deposit(mintAmount);

        // cst = ICST(wamuETH);
        // cETH.approve(wamuETH, mintAmount);
        // cst.deposit(mintAmount);

        // cst = ICST(mlETH);
        // cETH.approve(mlETH, mintAmount);
        // cst.deposit(mintAmount);

        // config.setModuleCore(address(moduleCore));
        // config.initializeModuleCore(bsETH, cETH, 0.3 ether, 20 ether);

        issueDSAndAddLiquidity(bsETH, ceth, 0.3 ether, 0.2 ether, 1 ether); // EarlyRedemptionFee = 0.3%,  DSPrice=0.2%(or 20%)  repurchaseFee = 1%
        issueDSAndAddLiquidity(lbETH, ceth, 0.3 ether, 0.3 ether, 0.5 ether); // EarlyRedemptionFee = 0.3%,  DSPrice=0.3%(or 30%)  repurchaseFee = 0.5%
        issueDSAndAddLiquidity(wamuETH, ceth, 0.3 ether, 0.7 ether, 0); // EarlyRedemptionFee = 0.3%,  DSPrice=0.3%(or 70%)  repurchaseFee = 0%
        issueDSAndAddLiquidity(mlETH, ceth, 0.3 ether, 0.3 ether, 0.25 ether); // EarlyRedemptionFee = 0.3%,  DSPrice=0.3%(or 30%)  repurchaseFee = 0.25%
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function issueDSAndAddLiquidity(
        address cst,
        address ceth,
        uint256 redmptionFee,
        uint256 dsPrice,
        uint256 repurchaseFee
    ) public {
        config.initializeModuleCore(cst, ceth, redmptionFee, dsPrice);

        Id id = moduleCore.getId(cst, ceth);
        config.issueNewDs(
            id,
            block.timestamp + 180 days, // 6 months
            1 ether, // exchange rate = 1:1
            repurchaseFee
        );
        console.log("New DS issued");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        cETH.approve(address(moduleCore), depositLVAmt);
        moduleCore.depositLv(id, depositLVAmt);
        console.log("LV Deposited");

        cETH.approve(address(univ2Router), liquidityAmt);
        IERC20(cst).approve(address(univ2Router), liquidityAmt);
        univ2Router.addLiquidity(
            ceth,
            cst,
            liquidityAmt,
            liquidityAmt,
            liquidityAmt,
            liquidityAmt,
            msg.sender,
            block.timestamp + 10000 minutes
        );
        console.log("Liquidity Added to AMM");
    }
}
