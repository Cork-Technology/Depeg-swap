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

interface ICST {
    function deposit(uint256 amount) external;
}

contract DeployScript is Script {
    // TODO : check if univ2 compilation with foundry is same as hardhat compiled bytecode
    string constant v2FactoryArtifact = "test/helper/ext-abi/foundry/uni-v2-factory.json";
    string constant v2RouterArtifact = "test/helper/ext-abi/foundry/uni-v2-router.json";

    IUniswapV2Factory public factory;
    IUniswapV2Router02 public univ2Router;

    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PRECENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    address bsETH = 0xcDD25693eb938B3441585eBDB4D766751fd3cdAD;
    address lbETH = 0xA00B0cC70dC182972289a0625D3E1eFCE6Aac624;
    address wamuETH = 0x79A8b67B51be1a9d18Cf88b4e287B46c73316d89;
    address mlETH = 0x68eb9E1bB42feef616BE433b51440D007D86738e;

    CETH cETH = CETH(ceth);

    uint256 depositLVAmt = 40_000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        if (!isProd && ceth == address(0)) {
            // Deploy the WETH contract
            cETH = new CETH();
            cETH.mint(msg.sender, 100_000_000_000_000 ether);
            ceth = address(cETH);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CETH                            : ", address(cETH));

            CST bsETHCST = new CST("Bear Sterns Restaked ETH", "bsETH", ceth, msg.sender, 48 hours);
            bsETH = address(bsETHCST);
            cETH.approve(bsETH, 500_000 ether);
            bsETHCST.deposit(500_000 ether);
            console.log("bsETH                           : ", address(bsETH));

            CST lbETHCST = new CST("Lehman Brothers Restaked ETH", "lbETH", ceth, msg.sender, 10 hours);
            lbETH = address(lbETHCST);
            cETH.approve(lbETH, 500_000 ether);
            lbETHCST.deposit(500_000 ether);
            console.log("lbETH                           : ", address(lbETH));

            CST wamuETHCST = new CST("Washington Mutual restaked ETH", "wamuETH", ceth, msg.sender, 1 seconds);
            wamuETH = address(wamuETHCST);
            cETH.approve(wamuETH, 500_000 ether);
            wamuETHCST.deposit(500_000 ether);
            console.log("wamuETH                         : ", address(wamuETH));

            CST mlETHCST = new CST("Merrill Lynch staked ETH", "mlETH", ceth, msg.sender, 5 hours);
            mlETH = address(mlETHCST);
            cETH.approve(mlETH, 10_000_000 ether);
            mlETHCST.deposit(10_000_000 ether);
            console.log("mlETH                           : ", address(mlETH));
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        } else {
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CETH USED                       : ", address(ceth));
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        }
        cETH = CETH(ceth);

        // Deploy the Asset Factory implementation (logic) contract
        AssetFactory assetFactoryImplementation = new AssetFactory();
        console.log("Asset Factory Implementation    : ", address(assetFactoryImplementation));

        // Deploy the Asset Factory Proxy contract
        bytes memory data = abi.encodeWithSelector(assetFactoryImplementation.initialize.selector);
        ERC1967Proxy assetFactoryProxy = new ERC1967Proxy(address(assetFactoryImplementation), data);
        assetFactory = AssetFactory(address(assetFactoryProxy));
        console.log("Asset Factory                   : ", address(assetFactory));

        // Deploy the CorkConfig contract
        config = new CorkConfig();
        console.log("Cork Config                     : ", address(config));

        // Deploy the FlashSwapRouter implementation (logic) contract
        RouterState routerImplementation = new RouterState();
        console.log("Flashswap Router Implementation : ", address(routerImplementation));

        // Deploy the FlashSwapRouter Proxy contract
        data = abi.encodeWithSelector(routerImplementation.initialize.selector, address(config));
        ERC1967Proxy routerProxy = new ERC1967Proxy(address(routerImplementation), data);
        flashswapRouter = RouterState(address(routerProxy));
        console.log("Flashswap Router Proxy          : ", address(flashswapRouter));

        // Deploy the UniswapV2Factory contract
        address _factory = deployCode(v2FactoryArtifact, abi.encode(msg.sender, address(flashswapRouter)));
        factory = IUniswapV2Factory(_factory);
        console.log("Univ2 Factory                   : ", _factory);

        // Deploy the UniswapV2Router contract
        address _router = deployCode(v2RouterArtifact, abi.encode(_factory, address(ceth), address(flashswapRouter)));
        univ2Router = IUniswapV2Router02(_router);
        console.log("Univ2 Router                    : ", _router);

        // Deploy the ModuleCore implementation (logic) contract
        ModuleCore moduleCoreImplementation = new ModuleCore();
        console.log("ModuleCore Router Implementation : ", address(moduleCoreImplementation));

        // Deploy the ModuleCore Proxy contract
        data = abi.encodeWithSelector(moduleCoreImplementation.initialize.selector);
        ERC1967Proxy moduleCoreProxy = new ERC1967Proxy(address(routerImplementation), data);
        moduleCore = ModuleCore(address(moduleCoreProxy));

        console.log("Module Core                     : ", address(moduleCore));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Transfer Ownership to moduleCore
        assetFactory.transferOwnership(address(moduleCore));
        // TODO
        // flashswapRouter.transferOwnership(address(moduleCore));
        console.log("Transferred ownerships to Modulecore");

        config.setModuleCore(address(moduleCore));
        console.log("Modulecore configured in Config contract");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        issueDSAndAddLiquidity(mlETH, ceth, 300_000 ether, 0.2 ether, 0.2 ether, 1 ether); // EarlyRedemptionFee = 0.2%,  DSPrice=0.2%(or 20%)  repurchaseFee = 1%
        issueDSAndAddLiquidity(lbETH, ceth, 300_000 ether, 0.2 ether, 0.3 ether, 0.5 ether); // EarlyRedemptionFee = 0.2%,  DSPrice=0.3%(or 30%)  repurchaseFee = 0.5%
        issueDSAndAddLiquidity(bsETH, ceth, 300_000 ether, 0.2 ether, 0.7 ether, 0); // EarlyRedemptionFee = 0.2%,  DSPrice=0.7%(or 70%)  repurchaseFee = 0%
        issueDSAndAddLiquidity(wamuETH, ceth, 500_000 ether, 0.2 ether, 0.3 ether, 0.25 ether); // EarlyRedemptionFee = 0.2%,  DSPrice=0.3%(or 30%)  repurchaseFee = 0.25%

        // moduleCore.redeemEarlyLv(id, msg.sender, 10 ether);
        // uint256 result = flashswapRouter.previewSwapRaforDs(id, 1, 100 ether);
        // console.log(result);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function issueDSAndAddLiquidity(
        address cst,
        address ceth,
        uint256 liquidityAmt,
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
            repurchaseFee,
            10, // TODO
            block.timestamp + 180 days // 6 months // TODO
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

        // moduleCore.redeemEarlyLv(id, msg.sender, 10 ether);
        // uint256 result = flashswapRouter.previewSwapRaforDs(id, 1, 100 ether);
        // console.log(result);
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
