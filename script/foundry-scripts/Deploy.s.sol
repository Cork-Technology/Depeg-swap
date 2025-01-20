pragma solidity ^0.8.24;

import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {HedgeUnit} from "../../contracts/core/assets/HedgeUnit.sol";
import {HedgeUnitFactory} from "../../contracts/core/assets/HedgeUnitFactory.sol";
import {HedgeUnitRouter} from "../../contracts/core/assets/HedgeUnitRouter.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import "./Utils/HookMiner.sol";
import {CorkHook, LiquidityToken, Hooks} from "Cork-Hook/CorkHook.sol";

interface ICST {
    function deposit(uint256 amount) external;
}

contract DeployScript is Script {
    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;
    PoolManager public poolManager;
    CorkHook public hook;
    LiquidityToken public liquidityToken;
    Liquidator public liquidator;
    HedgeUnitFactory public hedgeUnitFactory;
    HedgeUnitRouter public hedgeUnitRouter;

    HedgeUnit public hedgeUnitbsETH;
    HedgeUnit public hedgeUnitlbETH;
    HedgeUnit public hedgeUnitwamuETH;
    HedgeUnit public hedgeUnitmlETH;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    address internal constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    address bsETH = 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9;
    address lbETH = 0xF24177162B1604e56EB338dd9775d75CC79DaC2B;
    address wamuETH = 0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B;
    address mlETH = 0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6;
    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    uint256 mlETH_CETH_expiry = 4 days;
    uint256 lbETH_CETH_expiry = 4 days;
    uint256 bsETH_CETH_expiry = 0.4 days;
    uint256 wamuETH_CETH_expiry = 6 days;

    // TODO : plz fix this properly
    address hookTrampoline = vm.addr(pk);

    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens

    CETH cETH = CETH(ceth);

    uint256 depositLVAmt = 40_000 ether;

    uint160 hookFlags = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
    );

    function run() public {
        vm.startBroadcast(pk);
        if (!isProd && ceth == address(0)) {
            // Deploy the WETH contract
            cETH = new CETH();
            cETH.mint(msg.sender, 100_000_000_000_000 ether);
            ceth = address(cETH);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CETH                            : ", address(cETH));

            CST bsETHCST = new CST("Bear Sterns Restaked ETH", "bsETH", ceth, msg.sender, 480 hours, 7.5 ether);
            bsETH = address(bsETHCST);
            cETH.addMinter(bsETH);
            cETH.approve(bsETH, 500_000 ether);
            bsETHCST.deposit(500_000 ether);
            console.log("bsETH                           : ", address(bsETH));

            CST lbETHCST = new CST("Lehman Brothers Restaked ETH", "lbETH", ceth, msg.sender, 10 hours, 7.5 ether);
            lbETH = address(lbETHCST);
            cETH.addMinter(lbETH);
            cETH.approve(lbETH, 500_000 ether);
            lbETHCST.deposit(500_000 ether);
            console.log("lbETH                           : ", address(lbETH));

            CST wamuETHCST = new CST("Washington Mutual restaked ETH", "wamuETH", ceth, msg.sender, 1 seconds, 3 ether);
            wamuETH = address(wamuETHCST);
            cETH.addMinter(wamuETH);
            cETH.approve(wamuETH, 500_000 ether);
            wamuETHCST.deposit(500_000 ether);
            console.log("wamuETH                         : ", address(wamuETH));

            CST mlETHCST = new CST("Merrill Lynch staked ETH", "mlETH", ceth, msg.sender, 5 hours, 7.5 ether);
            mlETH = address(mlETHCST);
            cETH.addMinter(mlETH);
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
        config = new CorkConfig(deployer, deployer);
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
        // address _factory = deployCode(v2FactoryArtifact, abi.encode(msg.sender, address(flashswapRouter)));
        // factory = IUniswapV2Factory(_factory);
        // console.log("Univ2 Factory                   : ", _factory);

        // Deploy the UniswapV2Router contract
        // address _router = deployCode(v2RouterArtifact, abi.encode(_factory, address(ceth), address(flashswapRouter)));
        // univ2Router = IUniswapV2Router02(_router);
        // console.log("Univ2 Router                    : ", _router);

        // Deploy the ModuleCore implementation (logic) contract
        ModuleCore moduleCoreImplementation = new ModuleCore();
        console.log("ModuleCore Router Implementation : ", address(moduleCoreImplementation));

        // deploy hook
        poolManager = new PoolManager(deployer);
        liquidityToken = new LiquidityToken();

        bytes memory creationCode = type(CorkHook).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager, liquidityToken, address(config));

        (address hookAddress, bytes32 salt) = HookMiner.find(CREATE_2_PROXY, hookFlags, creationCode, constructorArgs);

        hook = new CorkHook{salt: salt}(poolManager, liquidityToken, address(config));
        require(address(hook) == hookAddress, "hook address mismatch");

        // Deploy the ModuleCore Proxy contract

        data = abi.encodeWithSelector(
            moduleCoreImplementation.initialize.selector,
            address(assetFactory),
            address(hook),
            address(flashswapRouter),
            address(config),
            0.2 ether
        ); // 0.2 base redemptionfee
        ERC1967Proxy moduleCoreProxy = new ERC1967Proxy(address(moduleCoreImplementation), data);
        moduleCore = ModuleCore(address(moduleCoreProxy));

        console.log("Module Core                     : ", address(moduleCore));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the Liquidator contract
        liquidator = new Liquidator(address(config), hookTrampoline, settlementContract, address(moduleCore));
        console.log("Liquidator                      : ", address(liquidator));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnitFactry contract
        hedgeUnitRouter = new HedgeUnitRouter();
        hedgeUnitFactory = new HedgeUnitFactory(address(moduleCore), address(config), address(flashswapRouter));
        hedgeUnitRouter.grantRole(hedgeUnitRouter.HEDGE_UNIT_FACTORY_ROLE(), address(hedgeUnitFactory));
        config.setHedgeUnitFactory(address(hedgeUnitFactory));
        console.log("HedgeUnit Factory               : ", address(hedgeUnitFactory));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnit contract
        hedgeUnitbsETH = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(bsETH, ceth, bsETH_CETH_expiry),
                bsETH,
                ceth,
                "Bear Sterns Restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU bsETH                        : ", address(hedgeUnitbsETH));

        hedgeUnitlbETH = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(lbETH, ceth, lbETH_CETH_expiry),
                lbETH,
                ceth,
                "Lehman Brothers Restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU lbETH                        : ", address(hedgeUnitlbETH));

        hedgeUnitwamuETH = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(wamuETH, ceth, wamuETH_CETH_expiry),
                wamuETH,
                ceth,
                "Washington Mutual restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU wamuETH                      : ", address(hedgeUnitwamuETH));

        hedgeUnitmlETH = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(mlETH, ceth, mlETH_CETH_expiry),
                mlETH,
                ceth,
                "Merrill Lynch staked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU mlETH                        : ", address(hedgeUnitmlETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Transfer Ownership to moduleCore
        assetFactory.transferOwnership(address(moduleCore));
        // TODO
        // flashswapRouter.transferOwnership(address(moduleCore));
        console.log("Transferred ownerships to Modulecore");

        config.setModuleCore(address(moduleCore));
        flashswapRouter.setModuleCore(address(moduleCore));
        console.log("Modulecore configured in Config contract");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        issueDSAndAddLiquidity(mlETH, ceth, 300_000 ether, 0, 0.005 ether, 1 ether, 4 days); // EarlyRedemptionFee = 0%,  DSPrice=0.2%(or 20%)  repurchaseFee = 1%
        issueDSAndAddLiquidity(lbETH, ceth, 300_000 ether, 0, 0.0075 ether, 0.5 ether, 4 days); // EarlyRedemptionFee = 0%,  DSPrice=0.3%(or 30%)  repurchaseFee = 0.5%
        issueDSAndAddLiquidity(bsETH, ceth, 300_000 ether, 0, 0.0175 ether, 0, 4 days); // EarlyRedemptionFee = 0%,  DSPrice=0.7%(or 70%)  repurchaseFee = 0%
        issueDSAndAddLiquidity(wamuETH, ceth, 500_000 ether, 0, 0.0045 ether, 0.25 ether, 6 days); // EarlyRedemptionFee = 0%,  DSPrice=0.3%(or 30%)  repurchaseFee = 0.25%

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
        uint256 repurchaseFee,
        uint256 expiryPeriod
    ) public {
        config.initializeModuleCore(cst, ceth, dsPrice, expiryPeriod);

        Id id = moduleCore.getId(cst, ceth, expiryPeriod);
        config.updatePsmBaseRedemptionFeePercentage(id, redmptionFee);
        config.issueNewDs(
            id,
            1 ether, // exchange rate = 1:1
            repurchaseFee,
            6 ether, // 6% per day TODO
            block.timestamp + 6600, // 1 block per 12 second and 22 hours rollover during TC = 6600 // TODO
            block.timestamp + 10 seconds
        );
        console.log("New DS issued");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // TODO : doesn't work properly for now
        // cETH.approve(address(moduleCore), depositLVAmt);
        // moduleCore.depositLv(id, depositLVAmt, 0, 0);
        // console.log("LV Deposited");

        // TODO : plz fix this properly
        // cETH.approve(address(univ2Router), liquidityAmt);
        // IERC20(cst).approve(address(univ2Router), liquidityAmt);
        // univ2Router.addLiquidity(
        //     ceth,
        //     cst,
        //     liquidityAmt,
        //     liquidityAmt,
        //     liquidityAmt,
        //     liquidityAmt,
        //     msg.sender,
        //     block.timestamp + 10000 minutes
        // );
        // console.log("Liquidity Added to AMM");

        // moduleCore.redeemEarlyLv(id, msg.sender, 10 ether);
        // uint256 result = flashswapRouter.previewSwapRaforDs(id, 1, 100 ether);
        // console.log(result);
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
