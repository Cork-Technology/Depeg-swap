pragma solidity 0.8.26;

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
import {CUSD} from "../../contracts/tokens/CUSD.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {HookMiner} from "./Utils/HookMiner.sol";
import {PoolKey, Currency, CorkHook, LiquidityToken, Hooks} from "Cork-Hook/CorkHook.sol";

contract DeployScript is Script {
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
    HedgeUnitRouter public hedgeUnitRouter;

    HedgeUnit public hedgeUnitbsETH;
    HedgeUnit public hedgeUnitlbETH;
    HedgeUnit public hedgeUnitwamuETH;
    HedgeUnit public hedgeUnitmlETH;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    address public cusd = vm.envAddress("CUSD");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address sender = vm.addr(pk);

    address internal constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    address wamuETH = 0x22222228802B45325E0b8D0152C633449Ab06913;
    address bsETH = 0x33333335a697843FDd47D599680Ccb91837F59aF;
    address mlETH = 0x44444447386435500C5a06B167269f42FA4ae8d4;
    address svbUSD = 0x5555555eBBf30a4b084078319Da2348fD7B9e470;
    address fedUSD = 0x666666685C211074C1b0cFed7e43E1e7D8749E43;
    address omgUSD = 0x7777777707136263F82775e7ED0Fc99Bbe6f5eB0;

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

    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens

    CETH cETH = CETH(ceth);
    CUSD cUSD = CUSD(cusd);

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

            cUSD = new CUSD("Cork Competition USD", "cUSD");
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
        cUSD = CUSD(cusd);

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

        // Deploy the ModuleCore implementation (logic) contract
        ModuleCore moduleCoreImplementation = new ModuleCore();
        console.log("ModuleCore Router Implementation: ", address(moduleCoreImplementation));

        // deploy hook
        poolManager = new PoolManager();
        console.log("Pool Manager                    : ", address(poolManager));
        liquidityToken = new LiquidityToken();
        console.log("Liquidity Token                 : ", address(liquidityToken));

        bytes memory creationCode = type(CorkHook).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager, liquidityToken, address(config));

        (address hookAddress, bytes32 salt) = HookMiner.find(CREATE_2_PROXY, hookFlags, creationCode, constructorArgs);

        hook = new CorkHook{salt: salt}(poolManager, liquidityToken, address(config));
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
        liquidator = new Liquidator(address(config), sender, settlementContract, address(moduleCore));
        console.log("Liquidator                      : ", address(liquidator));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnitFactry contract
        hedgeUnitRouter = new HedgeUnitRouter();
        hedgeUnitFactory = new HedgeUnitFactory(address(moduleCore), address(config), address(flashswapRouter), address(hedgeUnitRouter));
        hedgeUnitRouter.grantRole(hedgeUnitRouter.HEDGE_UNIT_FACTORY_ROLE(), address(hedgeUnitFactory));
        config.setHedgeUnitFactory(address(hedgeUnitFactory));
        console.log("HedgeUnit Factory               : ", address(hedgeUnitFactory));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnit contract
        hedgeUnitwamuETH = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(wamuETH, ceth, wamuETHExpiry),
                wamuETH,
                ceth,
                "Washington Mutual restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU wamuETH                      : ", address(hedgeUnitwamuETH));

        hedgeUnitbsETH = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(bsETH, wamuETH, bsETHExpiry),
                bsETH,
                wamuETH,
                "Bear Sterns Restaked ETH - wamuETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU bsETH                        : ", address(hedgeUnitbsETH));

        hedgeUnitmlETH = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(mlETH, ceth, mlETHExpiry),
                mlETH,
                bsETH,
                "Merrill Lynch staked ETH - bsETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU mlETH                        : ", address(hedgeUnitmlETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Transfer Ownership to moduleCore
        assetFactory.transferOwnership(address(moduleCore));
        // hook.transferOwnership(address(config));
        console.log("Transferred ownerships to Modulecore");

        config.setModuleCore(address(moduleCore));
        flashswapRouter.setModuleCore(address(moduleCore));
        console.log("Modulecore configured in Config contract");

        config.setHook(address(hook));
        flashswapRouter.setHook(address(hook));
        console.log("Hook configured in FlashswapRouter contract");

        univ2Router = IUniswapV2Router02(uniswapV2RouterSepolia);
        console.log("Univ2 Router                    : ", uniswapV2RouterSepolia);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // EarlyRedemptionFee = 0.2%,  DSPrice=1.285%  repurchaseFee = 0.75%
        issueDSAndDepositToLv(
            wamuETH, ceth, 0.2 ether, 1.285 ether, 0.75 ether, wamuETHExpiry, 30_000 ether, 0.15 ether
        );
        // EarlyRedemptionFee = 0.2%,  DSPrice=6.428%  repurchaseFee = 0.75%
        issueDSAndDepositToLv(bsETH, wamuETH, 0.2 ether, 6.428 ether, 0.75 ether, bsETHExpiry, 30_000 ether, 0.3 ether);
        // EarlyRedemptionFee = 0.2%,  DSPrice=7.5%  repurchaseFee = 0.75%
        issueDSAndDepositToLv(mlETH, bsETH, 0.2 ether, 7.5 ether, 0.75 ether, mlETHExpiry, 30_000 ether, 0.3 ether);

        issueDSAndDepositToLv(
            svbUSD, fedUSD, 0.2 ether, 8.571 ether, 0.75 ether, svbUSDExpiry, 75_000_000 ether, 0.3 ether
        );
        issueDSAndDepositToLv(
            fedUSD, cusd, 0.2 ether, 4.285 ether, 0.75 ether, fedUSDExpiry, 75_000_000 ether, 0.15 ether
        );
        issueDSAndDepositToLv(
            omgUSD, svbUSD, 0.08 ether, 5.1 ether, 0.75 ether, omgUSDExpiry, 75_000_000 ether, 0.3 ether
        );

        // Add liquidity for given pairs to AMM
        AddAMMLiquidity(wamuETH, ceth, 200_000 ether);
        AddAMMLiquidity(bsETH, ceth, 200_000 ether);
        AddAMMLiquidity(mlETH, ceth, 200_000 ether);
        AddAMMLiquidity(svbUSD, cusd, 500_000_000 ether);
        AddAMMLiquidity(fedUSD, cusd, 500_000_000 ether);
        AddAMMLiquidity(omgUSD, cusd, 500_000_000 ether);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function issueDSAndDepositToLv(
        address paToken,
        address raToken,
        uint256 redmptionFee,
        uint256 dsPrice,
        uint256 repurchaseFee,
        uint256 expiryPeriod,
        uint256 depositLVAmt,
        uint256 ammBaseFeePercentage
    ) public {
        config.initializeModuleCore(paToken, raToken, redmptionFee, dsPrice, base_redemption_fee, expiryPeriod);
        Id id = moduleCore.getId(paToken, raToken, expiryPeriod);
        config.issueNewDs(
            id,
            1 ether, // exchange rate = 1:1
            repurchaseFee,
            6 ether, // 6% per day TODO
            block.timestamp + 6600, // 1 block per 12 second and 22 hours rollover during TC = 6600 // TODO
            block.timestamp + 10 minutes
        );
        console.log("New DS issued");

        //Uniswap V4 constant
        // uint160 SQRT_PRICE_1_1 = 79228162514264337593543950336;

        (address ctToken,) = moduleCore.swapAsset(id, 1);
        // (address ra, address ct) = sortTokens(raToken, ctToken);
        // PoolKey memory key = PoolKey(Currency.wrap(address(ra)), Currency.wrap(address(ct)), 0, 1, hook);
        // poolManager.initialize(key, SQRT_PRICE_1_1);
        config.updateAmmBaseFeePercentage(raToken, ctToken, ammBaseFeePercentage);
        console.log("Initialised V4 RA-CT pool");

        CETH(raToken).approve(address(moduleCore), depositLVAmt);
        moduleCore.depositLv(id, depositLVAmt, 0, 0);
        console.log("LV Deposited");

        // moduleCore.redeemEarlyLv(id, sender, 10 ether);
        // uint256 result = flashswapRouter.previewSwapRaforDs(id, 1, 100 ether);
        // console.log(result);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }

    function AddAMMLiquidity(address paToken, address raToken, uint256 liquidityAmt) public {
        CETH(raToken).approve(uniswapV2RouterSepolia, liquidityAmt);
        IERC20(paToken).approve(uniswapV2RouterSepolia, liquidityAmt);
        univ2Router.addLiquidity(
            raToken,
            paToken,
            liquidityAmt,
            liquidityAmt,
            liquidityAmt,
            liquidityAmt,
            sender,
            block.timestamp + 10000 minutes
        );
        console.log("Liquidity Added to AMM");
    }

    // returns sorted token addresses, used to handle V4 pairs sorted in this order
    function sortTokens(address ra, address ct) internal pure returns (address token0, address token1) {
        assert(ra != ct);
        (token0, token1) = ra < ct ? (ra, ct) : (ct, ra);
        assert(token0 != address(0));
    }
}
