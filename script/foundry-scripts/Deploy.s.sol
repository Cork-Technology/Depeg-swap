pragma solidity 0.8.26;

import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../contracts/core/liquidators/Liquidator.sol";
import {HedgeUnit} from "../../contracts/core/assets/HedgeUnit.sol";
import {HedgeUnitFactory} from "../../contracts/core/assets/HedgeUnitFactory.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {HookMiner} from "./Utils/HookMiner.sol";
import {CorkHook, LiquidityToken, Hooks} from "Cork-Hook/CorkHook.sol";

interface ICST {
    function deposit(uint256 amount) external;
}

contract DeployScript is Script {
    // // TODO : check if univ2 compilation with foundry is same as hardhat compiled bytecode
    // string constant v2FactoryArtifact = "test/helper/ext-abi/foundry/uni-v2-factory.json";
    // string constant v2RouterArtifact = "test/helper/ext-abi/foundry/uni-v2-router.json";

    // IUniswapV2Factory public factory;
    IUniswapV2Router02 public univ2Router;

    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;
    PoolManager public poolManager;
    CorkHook public hook;
    LiquidityToken public liquidityToken;
    Liquidator public liquidator;
    HedgeUnitFactory public hedgeUnitFactory;

    HedgeUnit public hedgeUnitbsETH;
    HedgeUnit public hedgeUnitwamuETH;
    HedgeUnit public hedgeUnitmlETH;
    HedgeUnit public hedgeUnitsvbUSD;
    HedgeUnit public hedgeUnitfedUSD;
    HedgeUnit public hedgeUnitomgUSD;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    address public cusd = 0xEEeA08E6F6F5abC28c821Ffe2035326C6Bfd2017;
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address sender = vm.addr(pk);

    address internal constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    address bsETH = 0x0BAbf92b3e4fd64C26e1F6A05B59a7e0e0708378;
    address wamuETH = 0xd9682A7CE1C48f1de323E9b27A5D0ff0bAA24254;
    address mlETH = 0x98524CaB765Cb0De83F71871c56dc67C202e166d;
    address svbUSD = 0x7AE4c173d473218b59bF8A1479BFC706F28C635b;
    address fedUSD = 0xd8d134BEc26f7ebdAdC2508a403bf04bBC33fc7b;
    address omgUSD = 0x182733031965686043d5196207BeEE1dadEde818;

    // constants because they are external contracts
    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address uniswapV2FactorySepolia = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
    address uniswapV2RouterSepolia = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

    uint256 wamuETHExpiry = 3.5 days;
    uint256 bsETHExpiry = 3.5 days;
    uint256 mlETHExpiry = 1 days;
    uint256 svbUSDExpiry = 3.5 days;
    uint256 fedUSDExpiry = 3.5 days;
    uint256 omgUSDExpiry = 0.5 days;

    // TODO : plz fix this properly
    address hookTrampoline = vm.addr(pk);

    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens

    CETH cETH = CETH(ceth);
    CETH cUSD = CETH(cusd);

    uint160 hookFlags = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
    );

    function run() public {
        vm.startBroadcast(pk);
        if (!isProd && ceth == address(0)) {
            // Deploy the WETH contract
            cETH = new CETH("Cork Competition ETH", "cETH");
            cETH.mint(sender, 100_000_000_000_000 ether);
            ceth = address(cETH);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CETH                            : ", address(cETH));

            CST wamuETHCST = new CST("Washington Mutual restaked ETH", "wamuETH", ceth, sender, 480 hours, 3 ether);
            wamuETH = address(wamuETHCST);
            cETH.addMinter(wamuETH);
            cETH.approve(wamuETH, 1_000_000 ether);
            wamuETHCST.deposit(1_000_000 ether);
            console.log("wamuETH                         : ", address(wamuETH));

            CST bsETHCST = new CST("Bear Sterns Restaked ETH", "bsETH", ceth, sender, 480 hours, 10 ether);
            bsETH = address(bsETHCST);
            cETH.addMinter(bsETH);
            cETH.approve(bsETH, 1_000_000 ether);
            bsETHCST.deposit(1_000_000 ether);
            console.log("bsETH                           : ", address(bsETH));

            CST mlETHCST = new CST("Merrill Lynch staked ETH", "mlETH", ceth, sender, 480 hours, 10 ether);
            mlETH = address(mlETHCST);
            cETH.addMinter(mlETH);
            cETH.approve(mlETH, 1_000_000 ether);
            mlETHCST.deposit(1_000_000 ether);
            console.log("mlETH                           : ", address(mlETH));

            cUSD = new CETH("Cork Competition USD", "cUSD");
            cUSD.mint(sender, 100_000_000_000_000 ether);
            cusd = address(cUSD);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CUSD                            : ", address(cUSD));

            CST svbUSDCST = new CST("Sillycoin Valley Bank USD", "svbUSD", cusd, sender, 480 hours, 8 ether);
            svbUSD = address(svbUSDCST);
            cUSD.addMinter(svbUSD);
            cUSD.approve(svbUSD, 10_000_000_000 ether);
            svbUSDCST.deposit(10_000_000_000 ether);
            console.log("svbUSD                          : ", address(svbUSD));

            CST fedUSDCST = new CST("Fed Up USD", "fedUSD", cusd, sender, 480 hours, 5 ether);
            fedUSD = address(fedUSDCST);
            cUSD.addMinter(fedUSD);
            cUSD.approve(fedUSD, 10_000_000_000 ether);
            fedUSDCST.deposit(10_000_000_000 ether);
            console.log("fedUSD                          : ", address(fedUSD));

            CST omgUSDCST = new CST("Own My Gold USD", "omgUSD", cusd, sender, 480 hours, 0);
            omgUSD = address(omgUSDCST);
            cUSD.addMinter(omgUSD);
            cUSD.approve(omgUSD, 10_000_000_000 ether);
            omgUSDCST.deposit(10_000_000_000 ether);
            console.log("omgUSD                          : ", address(omgUSD));
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
        // address _factory = deployCode(v2FactoryArtifact, abi.encode(sender, address(flashswapRouter)));
        // factory = IUniswapV2Factory(_factory);
        // console.log("Univ2 Factory                   : ", _factory);

        // Deploy the UniswapV2Router contract
        // address _router = deployCode(v2RouterArtifact, abi.encode(_factory, address(ceth), address(flashswapRouter)));
        // univ2Router = IUniswapV2Router02(_router);
        // console.log("Univ2 Router                    : ", _router);

        // Deploy the ModuleCore implementation (logic) contract
        ModuleCore moduleCoreImplementation = new ModuleCore();
        console.log("ModuleCore Router Implementation: ", address(moduleCoreImplementation));

        // deploy hook
        poolManager = new PoolManager();
        console.log("Pool Manager                    : ", address(poolManager));
        liquidityToken = new LiquidityToken();
        console.log("Liquidity Token                 : ", address(liquidityToken));

        bytes memory creationCode = type(CorkHook).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager, liquidityToken);

        (address hookAddress, bytes32 salt) = HookMiner.find(CREATE_2_PROXY, hookFlags, creationCode, constructorArgs);

        hook = new CorkHook{salt: salt}(poolManager, liquidityToken);
        require(address(hook) == hookAddress, "hook address mismatch");
        console.log("Hook                            : ", hookAddress);

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
        liquidator = new Liquidator(msg.sender, hookTrampoline, settlementContract);
        console.log("Liquidator                      : ", address(liquidator));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnitFactry contract
        hedgeUnitFactory = new HedgeUnitFactory(address(moduleCore), address(liquidator));
        hedgeUnitFactory.updateLiquidatorRole(sender, true);
        console.log("HedgeUnit Factory               : ", address(hedgeUnitFactory));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnit contract

        hedgeUnitbsETH = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(bsETH, ceth, bsETH_CETH_expiry),
                bsETH,
                "Bear Sterns Restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU bsETH                        : ", address(hedgeUnitbsETH));

        hedgeUnitlbETH = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(lbETH, ceth, lbETH_CETH_expiry),
                lbETH,
                "Lehman Brothers Restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU lbETH                        : ", address(hedgeUnitlbETH));

        hedgeUnitwamuETH = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(wamuETH, ceth, wamuETHExpiry),
                wamuETH,
                "Washington Mutual restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU wamuETH                      : ", address(hedgeUnitwamuETH));

        hedgeUnitbsETH = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(bsETH, wamuETH, bsETHExpiry),
                bsETH,
                "Bear Sterns Restaked ETH - Washington Mutual restaked ETH",
                INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitbsETH), true);
        console.log("HU bsETH                        : ", address(hedgeUnitbsETH));

        hedgeUnitmlETH = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(mlETH, bsETH, mlETHExpiry),
                mlETH,
                "Merrill Lynch staked ETH - Bear Sterns Restaked ETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU mlETH                        : ", address(hedgeUnitmlETH));

        hedgeUnitfedUSD = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(fedUSD, cusd, fedUSDExpiry), fedUSD, "Fed Up USD - CUSD", INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitfedUSD), true);
        console.log("HU fedUSD                      : ", address(hedgeUnitfedUSD));

        hedgeUnitsvbUSD = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(svbUSD, fedUSD, svbUSDExpiry),
                svbUSD,
                "Sillycoin Valley Bank USD - Fed Up USD",
                INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitsvbUSD), true);
        console.log("HU svbUSD                      : ", address(hedgeUnitsvbUSD));

        hedgeUnitomgUSD = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(omgUSD, svbUSD, omgUSDExpiry),
                omgUSD,
                "Own My Gold USD - Sillycoin Valley Bank USD",
                INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitomgUSD), true);
        console.log("HU omgUSD                      : ", address(hedgeUnitomgUSD));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Transfer Ownership to moduleCore
        assetFactory.transferOwnership(address(moduleCore));
        // TODO
        // flashswapRouter.transferOwnership(address(moduleCore));
        console.log("Transferred ownerships to Modulecore");

        config.setModuleCore(address(moduleCore));
        flashswapRouter.setModuleCore(address(moduleCore));
        console.log("Modulecore configured in Config contract");

        flashswapRouter.setHook(address(hook));
        console.log("Hook configured in FlashswapRouter contract");

        univ2Router = IUniswapV2Router02(uniswapV2RouterSepolia);
        console.log("Univ2 Router                    : ", uniswapV2RouterSepolia);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // EarlyRedemptionFee = 0.2%,  DSPrice=0.2%(or 20%)  repurchaseFee = 0.75%
        issueDSAndAddLiquidity(
            wamuETH, ceth, 200_000 ether, 0.2 ether, 0.00375 ether, 0.75 ether, wamuETHExpiry, 30_000 ether
        );
        // EarlyRedemptionFee = 0.2%,  DSPrice=0.7%(or 70%)  repurchaseFee = 0.75%
        issueDSAndAddLiquidity(
            bsETH, wamuETH, 200_000 ether, 0.2 ether, 0.01875 ether, 0.75 ether, bsETHExpiry, 30_000 ether
        );
        // EarlyRedemptionFee = 0.2%,  DSPrice=0.3%(or 30%)  repurchaseFee = 0.75%
        issueDSAndAddLiquidity(
            mlETH, bsETH, 200_000 ether, 0.2 ether, 0.00625 ether, 0.75 ether, mlETHExpiry, 30_000 ether
        );

        issueDSAndAddLiquidity(
            svbUSD, fedUSD, 500_000_000 ether, 0.2 ether, 0.025 ether, 0.75 ether, svbUSDExpiry, 75_000_000 ether
        );
        issueDSAndAddLiquidity(
            fedUSD, cusd, 500_000_000 ether, 0.2 ether, 0.0125 ether, 0.75 ether, fedUSDExpiry, 75_000_000 ether
        );
        issueDSAndAddLiquidity(
            omgUSD, svbUSD, 500_000_000 ether, 0.08 ether, 0.002 ether, 0.75 ether, omgUSDExpiry, 75_000_000 ether
        );

        // moduleCore.redeemEarlyLv(id, sender, 10 ether);
        // uint256 result = flashswapRouter.previewSwapRaforDs(id, 1, 100 ether);
        // console.log(result);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function issueDSAndAddLiquidity(
        address cstToken,
        address cethToken,
        uint256 liquidityAmt,
        uint256 redmptionFee,
        uint256 dsPrice,
        uint256 repurchaseFee,
        uint256 expiryPeriod,
        uint256 depositLVAmt
    ) public {
        config.initializeModuleCore(cstToken, cethToken, redmptionFee, dsPrice, base_redemption_fee, expiryPeriod);

        Id id = moduleCore.getId(cstToken, cethToken, expiryPeriod);
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

        CETH(cethToken).approve(address(moduleCore), depositLVAmt);
        moduleCore.depositLv(id, depositLVAmt, 0, 0);
        console.log("LV Deposited");

        CETH(cethToken).approve(uniswapV2RouterSepolia, liquidityAmt);
        IERC20(cstToken).approve(uniswapV2RouterSepolia, liquidityAmt);
        univ2Router.addLiquidity(
            cethToken,
            cstToken,
            liquidityAmt,
            liquidityAmt,
            liquidityAmt,
            liquidityAmt,
            sender,
            block.timestamp + 10000 minutes
        );
        console.log("Liquidity Added to AMM");

        // moduleCore.redeemEarlyLv(id, sender, 10 ether);
        // uint256 result = flashswapRouter.previewSwapRaforDs(id, 1, 100 ether);
        // console.log(result);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
