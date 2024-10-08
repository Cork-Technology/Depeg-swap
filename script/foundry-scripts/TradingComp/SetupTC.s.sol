pragma solidity 0.8.24;

import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";

interface ICST {
    function deposit(uint256 amount) external;
}

contract SetupTCScript is Script {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public univ2Router;

    CorkConfig public config;
    ModuleCore public moduleCore;
    ICST public cst;
    IERC20 public cETH;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    uint256 mintAmount = 1_000_000_000_000 ether;
    uint256 depositLVAmt = 5000 ether;
    uint256 liquidityAmt = 1_000_000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        address bsETH = 0xcDD25693eb938B3441585eBDB4D766751fd3cdAD;
        address lbETH = 0xA00B0cC70dC182972289a0625D3E1eFCE6Aac624;
        address wamuETH = 0x79A8b67B51be1a9d18Cf88b4e287B46c73316d89;
        address mlETH = 0x68eb9E1bB42feef616BE433b51440D007D86738e;

        moduleCore = ModuleCore(0xa97e7b244B1C853b5981E2F74C133a68d9941F03);
        config = CorkConfig(0x25F8d3dB6c0cfC8815972C6Faaea875d48d1b401);
        univ2Router = IUniswapV2Router02(0x2eAc54667957a8a4312c92532df47eEBAE7bc36e);

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
        config.initializeModuleCore(cst, ceth, redmptionFee, dsPrice, base_redemption_fee);

        Id id = moduleCore.getId(cst, ceth);
        config.issueNewDs(
            id,
            block.timestamp + 180 days, // 6 months
            1 ether, // exchange rate = 1:1
            repurchaseFee,
            10, // TODO
            block.timestamp + 180 days,
            block.timestamp + 10 seconds
        );
        // 6 months // TODO

        console.log("New DS issued");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        cETH.approve(address(moduleCore), depositLVAmt);
        moduleCore.depositLv(id, depositLVAmt, 0, 0);
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
