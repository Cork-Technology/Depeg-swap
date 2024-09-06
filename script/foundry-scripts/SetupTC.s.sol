pragma solidity 0.8.24;

import {IUniswapV2Factory} from "uniswap-v2/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {DummyWETH} from "../../contracts/dummy/DummyWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Id} from "../../contracts/libraries/Pair.sol";

interface ICST {
    function deposit(uint256 amount) external;
}

contract SetupTCScript is Script {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public univ2Router;

    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;
    ICST public cst;
    IERC20 public cETH;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PRECENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        address bsETH = 0x47Ac327afFAf064Da7a42175D02cF4435E0d4088;
        address lbETH = 0x36645b1356c3a57A8ad401d274c5487Bc4A586B6;
        address wamuETH = 0x64BAdb1F23a409574441C10C2e0e9385E78bAD0F;
        address mlETH = 0x5FeB996d05633571C0d9A3E12A65B887a829f60b;

        moduleCore = ModuleCore(0xE843742Db2dfF75f5c5C4D524f9d05cf31f0006a);
        config = CorkConfig(0xd36179416804dAF522894fC74C7A79F21eEB8D4F);
        univ2Router = IUniswapV2Router02(0x2b1f46Bf510c5BD58490cF0131D68EaF6ffC7f7F);

        uint256 depositAmt = 1_000_000_000_000 ether;

        cETH = IERC20(ceth);

        // cst = ICST(bsETH);
        // cETH.approve(bsETH, depositAmt);
        // cst.deposit(depositAmt);

        // cst = ICST(lbETH);
        // cETH.approve(lbETH, depositAmt);
        // cst.deposit(depositAmt);

        // cst = ICST(wamuETH);
        // cETH.approve(wamuETH, depositAmt);
        // cst.deposit(depositAmt);

        // cst = ICST(mlETH);
        // cETH.approve(mlETH, depositAmt);
        // cst.deposit(depositAmt);

        // config.setModuleCore(address(moduleCore));
        // config.initializeModuleCore(bsETH, cETH, 0.3 ether, 20 ether);
        // config.issueNewDs(
        //     moduleCore.getId(bsETH, cETH),
        //     block.timestamp + 180 days,
        //     2 ether, // 2%
        //     1 ether // 1%
        // );
        // console.log("New DS issued");
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        Id id = moduleCore.getId(bsETH, ceth);
        cETH.approve(address(moduleCore), 5000 ether);
        moduleCore.depositLv(id, 5000 ether);

        univ2Router.addLiquidity(
            ceth,
            bsETH,
            1_000_000 ether,
            1_000_000 ether,
            1_000_000 ether,
            1_000_000 ether,
            msg.sender,
            block.timestamp + 10000 minutes
        );
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
