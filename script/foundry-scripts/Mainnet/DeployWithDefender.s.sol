pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {ProtectedUnit} from "../../../contracts/core/assets/ProtectedUnit.sol";
import {ProtectedUnitFactory} from "../../../contracts/core/assets/ProtectedUnitFactory.sol";
import {ProtectedUnitRouter} from "../../../contracts/core/assets/ProtectedUnitRouter.sol";
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
import {Defender, ApprovalProcessResponse} from "openzeppelin-foundry-upgrades/Defender.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployScript is Script {
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

    ProtectedUnit public protectedUnit_weth_wstETH;
    ProtectedUnit public protectedUnit_wstETH_weETH;
    ProtectedUnit public protectedUnit_sUSDS_USDe;
    ProtectedUnit public protectedUnit_sUSDe_USDT;

    address public defaultExchangeProvider;

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

    uint256 constant weth_wstETH_ARP = 1.5 ether;
    uint256 constant wstETH_weETH_ARP = 2 ether;
    uint256 constant sUSDS_USDe_ARP = 4 ether;
    uint256 constant sUSDe_USDT_ARP = 2 ether;

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

        ApprovalProcessResponse memory upgradeApprovalProcess = Defender.getUpgradeApprovalProcess();
        if (upgradeApprovalProcess.via == address(0)) {
            revert(
                string.concat(
                    "Upgrade approval process with id ",
                    upgradeApprovalProcess.approvalProcessId,
                    " has no assigned address"
                )
            );
        }
        Options memory opts;
        opts.defender.useDefenderDeploy = true;
        opts.defender.salt = "1001";

        bytes memory initializerData = abi.encodeWithSelector(AssetFactory.initialize.selector);
        address assetFactory = Upgrades.deployUUPSProxy("AssetFactory.sol", initializerData, opts);
        console.log("Deployed AssetFactory proxy : ", assetFactory);

        opts.defender.salt = "1002";
        address corkConfig = Defender.deployContract("CorkConfig.sol", opts);
        console.log("Deployed Cork-Config : ", corkConfig);

        opts.defender.salt = "1003";
        address routerImplementation = Defender.deployContract("FlashSwapRouter.sol", opts);
        console.log("Deployed FlashSwapRouter Implementation : ", routerImplementation);

        bytes memory data = abi.encodeWithSelector(RouterState.initialize.selector, corkConfig);
        ERC1967Proxy routerProxy = new ERC1967Proxy(routerImplementation, data);
        flashswapRouter = RouterState(address(routerProxy));
        console.log("Deployed FlashSwapRouter Proxy : ", address(flashswapRouter));

        opts.defender.salt = "1004";
        address moduleCoreImplementation = Defender.deployContract("ModuleCore.sol", opts);
        console.log("Deployed ModuleCore Implementation : ", moduleCoreImplementation);

        poolManager = new PoolManager(deployer);
        console.log("Deployed Pool Manager : ", address(poolManager));

        liquidityToken = new LiquidityToken();
        console.log("Deployed Liquidity Token : ", address(liquidityToken));

        bytes memory creationCode = type(CorkHook).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager, liquidityToken, corkConfig);

        (address hookAddress, bytes32 salt) = HookMiner.find(CREATE_2_PROXY, hookFlags, creationCode, constructorArgs);

        hook = new CorkHook{salt: salt}(poolManager, liquidityToken, corkConfig);
        require(address(hook) == hookAddress, "hook address mismatch");
        console.log("Deployed Hook : ", hookAddress);

        data = abi.encodeWithSelector(ModuleCore.initialize.selector, assetFactory, hook, flashswapRouter, corkConfig);
        ERC1967Proxy moduleCoreProxy = new ERC1967Proxy(moduleCoreImplementation, data);
        moduleCore = ModuleCore(address(moduleCoreProxy));
        console.log("Deployed Module Core : ", address(moduleCore));

        opts.defender.salt = "1005";
        address liquidatorAddress = Defender.deployContract("Liquidator.sol", opts);
        liquidator = Liquidator(liquidatorAddress);
        console.log("Deployed Liquidator : ", address(liquidator));

        opts.defender.salt = "1006";
        address protectedUnitRouterAddress = Defender.deployContract("ProtectedUnitRouter.sol", opts);
        protectedUnitRouter = ProtectedUnitRouter(protectedUnitRouterAddress);
        console.log("Deployed ProtectedUnit Router : ", address(protectedUnitRouter));

        opts.defender.salt = "1007";
        address protectedUnitFactoryAddress = Defender.deployContract("ProtectedUnitFactory.sol", opts);
        protectedUnitFactory = ProtectedUnitFactory(protectedUnitFactoryAddress);
        console.log("Deployed ProtectedUnit Factory : ", address(protectedUnitFactory));

        opts.defender.salt = "1008";
        address withdrawalAddress = Defender.deployContract("Withdrawal.sol", opts);
        withdrawal = Withdrawal(withdrawalAddress);
        console.log("Deployed Withdrawal : ", address(withdrawal));

        defaultExchangeProvider = corkConfig.defaultExchangeRateProvider();
        console.log("Exchange Rate Provider : ", defaultExchangeProvider);

        assetFactory.setModuleCore(address(moduleCore));
        hook.transferOwnership(address(corkConfig));
        console.log("Transferred ownerships to Modulecore");

        corkConfig.setModuleCore(address(moduleCore));
        corkConfig.setFlashSwapCore(address(flashswapRouter));
        corkConfig.setHook(address(hook));
        corkConfig.setProtectedUnitFactory(address(protectedUnitFactory));
        corkConfig.setTreasury(deployer);
        corkConfig.setWithdrawalContract(address(withdrawal));
        console.log("Contracts configured in Config");

        flashswapRouter.setModuleCore(address(moduleCore));
        flashswapRouter.setHook(address(hook));
        console.log("Contracts configured in Modulecore");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // // Deploy the CorkConfig contract
        // config = new CorkConfig(deployer, deployer);
        // console.log("Cork Config                     : ", address(config));

        // // Deploy the FlashSwapRouter implementation (logic) contract
        // RouterState routerImplementation = new RouterState();
        // console.log("Flashswap Router Implementation : ", address(routerImplementation));

        // // Deploy the FlashSwapRouter Proxy contract
        // data = abi.encodeWithSelector(routerImplementation.initialize.selector, address(config));
        // ERC1967Proxy routerProxy = new ERC1967Proxy(address(routerImplementation), data);
        // flashswapRouter = RouterState(address(routerProxy));
        // console.log("Flashswap Router Proxy          : ", address(flashswapRouter));

        // // Deploy the ModuleCore implementation (logic) contract
        // ModuleCore moduleCoreImplementation = new ModuleCore();
        // console.log("ModuleCore Router Implementation: ", address(moduleCoreImplementation));

        // // deploy hook
        // poolManager = new PoolManager(deployer);
        // console.log("Pool Manager                    : ", address(poolManager));
        // liquidityToken = new LiquidityToken();
        // console.log("Liquidity Token                 : ", address(liquidityToken));

        // bytes memory creationCode = type(CorkHook).creationCode;
        // bytes memory constructorArgs = abi.encode(poolManager, liquidityToken, address(config));

        // (address hookAddress, bytes32 salt) = HookMiner.find(CREATE_2_PROXY, hookFlags, creationCode, constructorArgs);

        // hook = new CorkHook{salt: salt}(poolManager, liquidityToken, address(config));
        // require(address(hook) == hookAddress, "hook address mismatch");
        // console.log("Hook                            : ", hookAddress);

        // // Deploy the ModuleCore Proxy contract
        // data = abi.encodeWithSelector(
        //     moduleCoreImplementation.initialize.selector,
        //     address(assetFactory),
        //     address(hook),
        //     address(flashswapRouter),
        //     address(config)
        // );
        // ERC1967Proxy moduleCoreProxy = new ERC1967Proxy(address(moduleCoreImplementation), data);
        // moduleCore = ModuleCore(address(moduleCoreProxy));

        // console.log("Module Core                     : ", address(moduleCore));
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // // Deploy the Liquidator contract
        // liquidator = new Liquidator(address(config), deployer, SETTLEMENT_CONTRACT, address(moduleCore));
        // console.log("Liquidator                      : ", address(liquidator));
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // // // Deploy the ProtectedUnitFactry contract
        // // protectedUnitRouter = new ProtectedUnitRouter();
        // // console.log("ProtectedUnit Router            : ", address(protectedUnitRouter));

        // // protectedUnitFactory = new ProtectedUnitFactory(address(moduleCore), address(config), address(flashswapRouter));
        // // config.setProtectedUnitFactory(address(protectedUnitFactory));
        // // console.log("ProtectedUnit Factory           : ", address(protectedUnitFactory));

        // withdrawal = new Withdrawal(address(moduleCore));
        // console.log("Withdrawal                      : ", address(withdrawal));

        // defaultExchangeProvider = address(config.defaultExchangeRateProvider());
        // console.log("Exchange Rate Provider          : ", defaultExchangeProvider);
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // assetFactory.setModuleCore(address(moduleCore));
        // // hook.transferOwnership(address(config));
        // console.log("Transferred ownerships to Modulecore");

        // config.setModuleCore(address(moduleCore));
        // config.setFlashSwapCore(address(flashswapRouter));
        // config.setHook(address(hook));
        // // config.setProtectedUnitFactory(address(protectedUnitFactory));
        // config.setTreasury(deployer);
        // config.setWithdrawalContract(address(withdrawal));
        // console.log("Contracts configured in Config");

        // flashswapRouter.setModuleCore(address(moduleCore));
        // flashswapRouter.setHook(address(hook));
        // console.log("Contracts configured in Modulecore");
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
