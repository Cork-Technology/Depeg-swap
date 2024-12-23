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

// Deployments --> all deployments successful except Uniswap V2 contract 
// asset Factory Implementation - done
// asset Factory Proxy - done
// CorkConfig contract - done
// FlashSwapRouter implementation (logic) contract - done
// FlashSwapRouter proxie contract - done
// ModuleCore implementation (logic) contract - done
// ModuleCore Proxy contract - done
// Liquidator = done

// Undeployed - Uniswap V2 router and implementation            - ask karan

// upgrade, transfer Ownership
//  assetFactory - done
// ModuleCore - done
// Cork Config - done 
// flashswaprouter - done 
// liquidator - undone 
// hedge unit 
// hook 

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

    HedgeUnit public hedgeUnitbsETH;
    HedgeUnit public hedgeUnitlbETH;
    HedgeUnit public hedgeUnitwamuETH;
    HedgeUnit public hedgeUnitmlETH;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

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
        console.log("ModuleCore Router Implementation : ", address(moduleCoreImplementation));

        // deploy hook
        poolManager = new PoolManager();
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

        console.log("Checking the roles before transferring AdminRoles");
        testAdminRoles(0x998e15be45A6A3E1C9a824c1Ef1Aaa4C988EC29F);

        console.log("Calling the Transfer Role function to tranfer admin roles");
        setupAdminRoles(0x12f8Bf2D209Cb8CBE604ff58CB6249b1Ba03ecbB);
    }

    function setupAdminRoles(address newAdmin) internal {
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Transferring the roles now");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        assetFactory.transferOwnership(newAdmin);

        // transferring cork config ownership
        bytes32 role = keccak256("MANAGER_ROLE");
        config.grantRole(role, newAdmin);
        bool afterRole = config.hasRole(role, newAdmin);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        require(afterRole == true, "Cork Conifg Role has been transffered successfully");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        moduleCore.transferOwnership(newAdmin);
        // liquidator.transferOwnership(newAdmin);
        // hedgeUnitFactory.transferOwnership(newAdmin);
        // hook.transferOwnership(newAdmin);

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Roles have been transferred");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        require(assetFactory.owner() == newAdmin, "AssetFactory ownership  transferred");
      
        flashswapRouter.grantRole(0x00,newAdmin );
        bool newRoleFlash = flashswapRouter.hasRole(0x00, newAdmin );
        require(newRoleFlash == true, "Flash Swap admin role successfully transeffered");




        require(moduleCore.owner() == newAdmin, "ModuleCore ownership  transferred");
        // require(liquidator.owner() == newAdmin, "Liquidator ownership  transferred");
        // require(hedgeUnitFactory.owner() == newAdmin, "HedgeUnitFactory ownership  transferred");
        // require(hook.owner() == newAdmin, "CorkHook ownership  transferred");

        console.log("Admin roles set up successfully and Verified and the new admin is :::::::::::::::    ", newAdmin);
    }

    function testAdminRoles(address admin) public {
        require(assetFactory.owner() == admin, "AssetFactory ownership not transferred");

        // testing for ownership of CorkConfig
        bool beforeRole = config.hasRole(keccak256("MANAGER_ROLE"), 0x998e15be45A6A3E1C9a824c1Ef1Aaa4C988EC29F);
        require(beforeRole == true, "Constrictor not setting Manager Role");

        // require(flashswapRouter.owner() == admin, "RouterState ownership not transferred");    
        bool beforeRoleFlashSwap = flashswapRouter.hasRole(0x00, 0x998e15be45A6A3E1C9a824c1Ef1Aaa4C988EC29F );
        require(beforeRoleFlashSwap == true, "FlashSwapRouter not setting the deployer as DEFAULT_ADMIN_ROLE");
   



        require(moduleCore.owner() == admin, "ModuleCore ownership not transferred");
        // require(liquidator.owner() == admin, "Liquidator ownership not transferred");
        // require(hook.owner() == admin, "CorkHook ownership not transferred");

        console.log("All admin roles remain the same as deployer");
    }
}
