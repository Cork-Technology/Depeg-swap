pragma solidity 0.8.24;

import {IUniswapV2Factory} from "uniswap-v2/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";

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

    address bsETH = 0x47Ac327afFAf064Da7a42175D02cF4435E0d4088;
    address lbETH = 0x36645b1356c3a57A8ad401d274c5487Bc4A586B6;
    address wamuETH = 0x64BAdb1F23a409574441C10C2e0e9385E78bAD0F;
    address mlETH = 0x5FeB996d05633571C0d9A3E12A65B887a829f60b;

    uint256 depositAmt = 1_000_000_000_000 ether;
    CETH cETH = CETH(ceth);

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        if (!isProd && ceth == address(0)) {
            // Deploy the WETH contract
            CETH weth = new CETH();
            weth.mint(msg.sender, 100_000_000_000_000 ether);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("WETH                            : ", address(weth));
            ceth = address(weth);

            CST bsETHCST = new CST("Bear Sterns Restaked ETH", "bsETH", ceth, msg.sender);
            bsETH = address(bsETHCST);
            weth.approve(bsETH, depositAmt);
            bsETHCST.deposit(depositAmt);

            CST lbETHCST = new CST("Lehman Brothers Restaked ETH", "lbETH", ceth, msg.sender);
            lbETH = address(lbETHCST);
            weth.approve(lbETH, depositAmt);
            lbETHCST.deposit(depositAmt);

            CST wamuETHCST = new CST("Washington Mutual restaked ETH", "wamuETH", ceth, msg.sender);
            wamuETH = address(wamuETHCST);
            weth.approve(wamuETH, depositAmt);
            wamuETHCST.deposit(depositAmt);

            CST mlETHCST = new CST("Merrill Lynch staked ETH", "mlETH", ceth, msg.sender);
            mlETH = address(mlETHCST);
            weth.approve(mlETH, depositAmt);
            mlETHCST.deposit(depositAmt);
        } else {
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
            console.log("CETH USED                       : ", address(ceth));
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        }

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
        data = abi.encodeWithSelector(routerImplementation.initialize.selector);
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

        // Deploy the ModuleCore contract
        moduleCore = new ModuleCore(
            address(assetFactory), _factory, address(flashswapRouter), _router, address(config), base_redemption_fee
        );
        console.log("Module Core                     : ", address(moduleCore));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Transfer Ownership to moduleCore
        assetFactory.transferOwnership(address(moduleCore));
        flashswapRouter.transferOwnership(address(moduleCore));
        console.log("Transferred ownerships to Modulecore");

        config.setModuleCore(address(moduleCore));
        console.log("Modulecore configured in Config contract");

        config.initializeModuleCore(bsETH, ceth, 0.3 ether, 0.2 ether); // LVFee = 0.3%,  DSPrice=20%(TODO : or maybe 0.2%)
        console.log("Modulecore initialized");

        Id id = moduleCore.getId(bsETH, ceth);
        config.issueNewDs(
            id,
            block.timestamp + 180 days, // 6 months
            2 ether, // 2%
            1 ether // 1%
        );
        console.log("New DS issued");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        cETH.approve(address(moduleCore), 5000 ether);
        moduleCore.depositLv(id, 5000 ether);

        // univ2Router.addLiquidity(
        //     ceth,
        //     bsETH,
        //     1_000_000 ether,
        //     1_000_000 ether,
        //     1_000_000 ether,
        //     1_000_000 ether,
        //     msg.sender,
        //     block.timestamp + 10000 minutes
        // );
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
