pragma solidity 0.8.26;

import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "contracts/core/CorkConfig.sol";
import {RouterState} from "contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "contracts/core/ModuleCore.sol";
import {Liquidator} from "contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {ProtectedUnit} from "contracts/core/assets/ProtectedUnit.sol";
import {ProtectedUnitFactory} from "contracts/core/assets/ProtectedUnitFactory.sol";
import {ProtectedUnitRouter} from "contracts/core/assets/ProtectedUnitRouter.sol";
import {CETH} from "contracts/tokens/CETH.sol";
import {CUSD} from "contracts/tokens/CUSD.sol";
import {CST} from "contracts/tokens/CST.sol";
import {Id} from "contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {HookMiner} from "../Utils/HookMiner.sol";
import {PoolKey, Currency, CorkHook, LiquidityToken, Hooks} from "Cork-Hook/CorkHook.sol";
import {Withdrawal} from "contracts/core/Withdrawal.sol";

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
    ProtectedUnitFactory public protectedUnitFactory;
    ProtectedUnitRouter public protectedUnitRouter;
    Withdrawal public withdrawal;
    address public exchangeRateProvider;

    ProtectedUnit public protectedUnitBsETH;
    ProtectedUnit public protectedUnitWamuETH;
    ProtectedUnit public protectedUnitMlETH;
    ProtectedUnit public protectedUnitSvbUSD;
    ProtectedUnit public protectedUnitFedUSD;
    ProtectedUnit public protectedUnitOmgUSD;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    address public cusd = vm.envAddress("CUSD");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    address internal constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

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

    uint256 constant INITIAL_MINT_CAP = 10000 * 1e18; // 10000 tokens

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
            cETH.mint(deployer, 100_000_000_000_000 ether);
            ceth = address(cETH);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CETH                            : ", address(cETH));

            CST wamuETHCST = new CST("Washington Mutual restaked ETH", "wamuETH", ceth, deployer, 480 hours, 3 ether);
            wamuETH = address(wamuETHCST);
            cETH.addMinter(wamuETH);
            cETH.approve(wamuETH, 1_000_000 ether);
            wamuETHCST.deposit(1_000_000 ether);
            console.log("wamuETH                         : ", address(wamuETH));

            CST bsETHCST = new CST("Bear Sterns Restaked ETH", "bsETH", ceth, deployer, 480 hours, 10 ether);
            bsETH = address(bsETHCST);
            cETH.addMinter(bsETH);
            cETH.approve(bsETH, 1_000_000 ether);
            bsETHCST.deposit(1_000_000 ether);
            console.log("bsETH                           : ", address(bsETH));

            CST mlETHCST = new CST("Merrill Lynch staked ETH", "mlETH", ceth, deployer, 480 hours, 10 ether);
            mlETH = address(mlETHCST);
            cETH.addMinter(mlETH);
            cETH.approve(mlETH, 1_000_000 ether);
            mlETHCST.deposit(1_000_000 ether);
            console.log("mlETH                           : ", address(mlETH));

            cUSD = new CUSD("Cork Competition USD", "cUSD");
            cUSD.mint(deployer, 100_000_000_000_000 ether);
            cusd = address(cUSD);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CUSD                            : ", address(cUSD));

            CST svbUSDCST = new CST("Sillycoin Valley Bank USD", "svbUSD", cusd, deployer, 480 hours, 8 ether);
            svbUSD = address(svbUSDCST);
            cUSD.addMinter(svbUSD);
            cUSD.approve(svbUSD, 10_000_000_000 ether);
            svbUSDCST.deposit(10_000_000_000 ether);
            console.log("svbUSD                          : ", address(svbUSD));

            CST fedUSDCST = new CST("Fed Up USD", "fedUSD", cusd, deployer, 480 hours, 5 ether);
            fedUSD = address(fedUSDCST);
            cUSD.addMinter(fedUSD);
            cUSD.approve(fedUSD, 10_000_000_000 ether);
            fedUSDCST.deposit(10_000_000_000 ether);
            console.log("fedUSD                          : ", address(fedUSD));

            CST omgUSDCST = new CST("Own My Gold USD", "omgUSD", cusd, deployer, 480 hours, 0);
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

        // Deploy the ModuleCore implementation (logic) contract
        ModuleCore moduleCoreImplementation = new ModuleCore();
        console.log("ModuleCore Router Implementation: ", address(moduleCoreImplementation));

        // deploy hook
        poolManager = new PoolManager(deployer);
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
            address(config)
        );
        ERC1967Proxy moduleCoreProxy = new ERC1967Proxy(address(moduleCoreImplementation), data);
        moduleCore = ModuleCore(address(moduleCoreProxy));

        console.log("Module Core                     : ", address(moduleCore));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the Liquidator contract
        liquidator = new Liquidator(address(config), deployer, settlementContract, address(moduleCore));
        console.log("Liquidator                      : ", address(liquidator));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the ProtectedUnitRouter contract
        protectedUnitRouter = new ProtectedUnitRouter(PERMIT2);
        console.log("ProtectedUnit Router            : ", address(protectedUnitRouter));

        // Deploy the ProtectedUnitFactory implementation (logic) contract
        ProtectedUnitFactory protectedUnitFactoryImpl = new ProtectedUnitFactory();
        console.log("ProtectedUnitFactory Implementation: ", address(protectedUnitFactoryImpl));

        data = abi.encodeWithSelector(
            protectedUnitFactoryImpl.initialize.selector,
            address(moduleCore),
            address(config),
            address(flashswapRouter),
            address(PERMIT2)
        );
        ERC1967Proxy protectedUnitFactoryProxy = new ERC1967Proxy(address(protectedUnitFactoryImpl), data);
        protectedUnitFactory = ProtectedUnitFactory(address(protectedUnitFactoryProxy));
        console.log("ProtectedUnit Factory           : ", address(protectedUnitFactory));

        config.setProtectedUnitFactory(address(protectedUnitFactory));
        console.log("ProtectedUnit Factory configured in Config contract");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the Withdrawal contract
        withdrawal = new Withdrawal(address(moduleCore));
        console.log("Withdrawal                      : ", address(withdrawal));

        exchangeRateProvider = address(config.defaultExchangeRateProvider());
        console.log("Exchange Rate Provider          : ", exchangeRateProvider);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Set the module core in the Asset Factory contract
        assetFactory.setModuleCore(address(moduleCore));
        // hook.transferOwnership(address(config));
        console.log("Transferred ownerships to Modulecore");

        config.setModuleCore(address(moduleCore));
        flashswapRouter.setModuleCore(address(moduleCore));
        console.log("Modulecore configured in Config contract");

        config.setHook(address(hook));
        flashswapRouter.setHook(address(hook));
        console.log("Hook configured in FlashswapRouter contract");

        config.setWithdrawalContract(address(withdrawal));
        console.log("Withdrawal contract configured in Config contract");

        config.setTreasury(deployer);
        console.log("Set treasury in Config contract");

        univ2Router = IUniswapV2Router02(uniswapV2RouterSepolia);
        console.log("Univ2 Router                    : ", uniswapV2RouterSepolia);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the ProtectedUnit contract
        // All have mint cap of 10000 tokens
        protectedUnitWamuETH = ProtectedUnit(
            config.deployProtectedUnit(
                moduleCore.getId(wamuETH, ceth, 1.285 ether, wamuETHExpiry, exchangeRateProvider),
                wamuETH,
                ceth,
                "wamuETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU wamuETH                      : ", address(protectedUnitWamuETH));

        protectedUnitBsETH = ProtectedUnit(
            config.deployProtectedUnit(
                moduleCore.getId(bsETH, wamuETH, 6.428 ether, bsETHExpiry, exchangeRateProvider),
                bsETH,
                wamuETH,
                "bsETH - wamuETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU bsETH                        : ", address(protectedUnitBsETH));

        protectedUnitMlETH = ProtectedUnit(
            config.deployProtectedUnit(
                moduleCore.getId(mlETH, bsETH, 7.5 ether, mlETHExpiry, exchangeRateProvider),
                mlETH,
                bsETH,
                "mlETH - bsETH",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU mlETH                        : ", address(protectedUnitMlETH));

        protectedUnitSvbUSD = ProtectedUnit(
            config.deployProtectedUnit(
                moduleCore.getId(svbUSD, fedUSD, 8.571 ether, svbUSDExpiry, exchangeRateProvider),
                svbUSD,
                fedUSD,
                "svbUSD - fedUSD",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU svbUSD                       : ", address(protectedUnitSvbUSD));

        protectedUnitFedUSD = ProtectedUnit(
            config.deployProtectedUnit(
                moduleCore.getId(fedUSD, cusd, 4.285 ether, fedUSDExpiry, exchangeRateProvider),
                fedUSD,
                cusd,
                "fedUSD - cUSD",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU fedUSD                       : ", address(protectedUnitFedUSD));

        protectedUnitOmgUSD = ProtectedUnit(
            config.deployProtectedUnit(
                moduleCore.getId(omgUSD, svbUSD, 5.1 ether, omgUSDExpiry, exchangeRateProvider),
                omgUSD,
                svbUSD,
                "omgUSD - svbUSD",
                INITIAL_MINT_CAP
            )
        );
        console.log("HU omgUSD                       : ", address(protectedUnitOmgUSD));
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
        config.initializeModuleCore(paToken, raToken, dsPrice, expiryPeriod, exchangeRateProvider);
        Id id = moduleCore.getId(paToken, raToken, dsPrice, expiryPeriod, exchangeRateProvider);
        config.updatePsmRate(id, 1 ether);

        config.issueNewDs(id, block.timestamp + 10 minutes);
        console.log("New DS issued");

        config.updatePsmBaseRedemptionFeePercentage(id, redmptionFee);
        config.updateRepurchaseFeeRate(id, repurchaseFee);
        config.updateAmmBaseFeePercentage(id, ammBaseFeePercentage);
        console.log("Updated fees");

        CETH(raToken).approve(address(moduleCore), depositLVAmt);
        moduleCore.depositLv(id, depositLVAmt, 0, 0, 0, 0);
        console.log("LV Deposited");
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
            deployer,
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
