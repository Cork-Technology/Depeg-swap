pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {HedgeUnit} from "../../../contracts/core/assets/HedgeUnit.sol";
import {HedgeUnitFactory} from "../../../contracts/core/assets/HedgeUnitFactory.sol";
import {HedgeUnitRouter} from "../../../contracts/core/assets/HedgeUnitRouter.sol";
import {CETH} from "../../../contracts/tokens/CETH.sol";
import {CUSD} from "../../../contracts/tokens/CUSD.sol";
import {CST} from "../../../contracts/tokens/CST.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {HookMiner} from "../Utils/HookMiner.sol";
import {PoolKey, Currency, CorkHook, LiquidityToken, Hooks} from "Cork-Hook/CorkHook.sol";
import {Withdrawal} from "../../../contracts/core/Withdrawal.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

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
    Withdrawal public withdrawal;

    HedgeUnit public hedgeUnit_weth_wstETH;
    HedgeUnit public hedgeUnit_wstETH_weETH;
    HedgeUnit public hedgeUnit_sUSDS_USDe;
    HedgeUnit public hedgeUnit_sUSDe_USDT;

    // constants because they are external contracts
    address constant SETTLEMENT_CONTRACT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint256 constant weth_wstETH_Expiry = 90 days;
    uint256 constant wstETH_weETH_Expiry = 90 days;
    uint256 constant sUSDS_USDe_Expiry = 90 days;
    uint256 constant sUSDe_USDT_Expiry = 90 days;

    uint256 constant INITIAL_MINT_CAP = 1_000_000 ether; // Cap of 1 million

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    uint160 hookFlags = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
    );

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Deployer                        : ", deployer);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

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
        liquidator = new Liquidator(address(config), deployer, SETTLEMENT_CONTRACT, address(moduleCore));
        console.log("Liquidator                      : ", address(liquidator));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnitFactry contract
        hedgeUnitRouter = new HedgeUnitRouter();
        console.log("HedgeUnit Router                : ", address(hedgeUnitRouter));

        hedgeUnitFactory = new HedgeUnitFactory(address(moduleCore), address(config), address(flashswapRouter));
        config.setHedgeUnitFactory(address(hedgeUnitFactory));
        console.log("HedgeUnit Factory               : ", address(hedgeUnitFactory));

        withdrawal = new Withdrawal(address(moduleCore));
        console.log("Withdrawal                      : ", address(withdrawal));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

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
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        deployProtectedUnits(
            wstETH, weth, weth_wstETH_Expiry, string.concat("PU", ERC20(weth).symbol(), "-", ERC20(wstETH).symbol())
        );
        deployProtectedUnits(
            weETH, wstETH, wstETH_weETH_Expiry, string.concat("PU", ERC20(wstETH).symbol(), "-", ERC20(weETH).symbol())
        );
        deployProtectedUnits(
            USDe, sUSDS, sUSDS_USDe_Expiry, string.concat("PU", ERC20(sUSDS).symbol(), "-", ERC20(USDe).symbol())
        );
        deployProtectedUnits(
            USDT, sUSDe, sUSDe_USDT_Expiry, string.concat("PU", ERC20(sUSDe).symbol(), "-", ERC20(USDT).symbol())
        );
        vm.stopBroadcast();
    }

    function deployProtectedUnits(address paToken, address raToken, uint256 expiryPeriod, string memory pairName)
        public
    {
        console.log("Pair: ", ERC20(raToken).name(), "-", ERC20(paToken).name());

        HedgeUnit protectedUnit = HedgeUnit(
            config.deployHedgeUnit(
                moduleCore.getId(paToken, raToken, expiryPeriod), paToken, raToken, pairName, INITIAL_MINT_CAP
            )
        );
        console.log("PU address                      : ", address(protectedUnit));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
