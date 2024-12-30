pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {HedgeUnit} from "../../contracts/core/assets/HedgeUnit.sol";
import {HedgeUnitFactory} from "../../contracts/core/assets/HedgeUnitFactory.sol";
import {HedgeUnitRouter} from "../../contracts/core/assets/HedgeUnitRouter.sol";
import {CorkConfig} from "../../contracts/core/CorkConfig.sol";

contract DeployHedgeUnitsScript is Script {
    ModuleCore public moduleCore;
    Liquidator public liquidator;
    CorkConfig public config;
    HedgeUnitFactory public hedgeUnitFactory;
    HedgeUnitRouter public hedgeUnitRouter;
    address flashSwapRouter;

    HedgeUnit public hedgeUnitbsETH;
    HedgeUnit public hedgeUnitwamuETH;
    HedgeUnit public hedgeUnitmlETH;
    HedgeUnit public hedgeUnitsvbUSD;
    HedgeUnit public hedgeUnitfedUSD;
    HedgeUnit public hedgeUnitomgUSD;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address sender = vm.addr(pk);

    address ceth = 0x0000000237805496906796B1e767640a804576DF;
    address cUSD = 0x1111111A3Ae9c9b133Ea86BdDa837E7E796450EA;
    address wamuETH = 0x22222228802B45325E0b8D0152C633449Ab06913;
    address bsETH = 0x33333335a697843FDd47D599680Ccb91837F59aF;
    address mlETH = 0x44444447386435500C5a06B167269f42FA4ae8d4;
    address svbUSD = 0x5555555eBBf30a4b084078319Da2348fD7B9e470;
    address fedUSD = 0x666666685C211074C1b0cFed7e43E1e7D8749E43;
    address omgUSD = 0x7777777707136263F82775e7ED0Fc99Bbe6f5eB0;

    uint256 wamuETHExpiry = 3.5 days;
    uint256 bsETHExpiry = 3.5 days;
    uint256 mlETHExpiry = 1 days;
    uint256 svbUSDExpiry = 3.5 days;
    uint256 fedUSDExpiry = 3.5 days;
    uint256 omgUSDExpiry = 0.5 days;

    // TODO: Add the hookTrampoline address
    address hookTrampoline = vm.addr(pk);

    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        moduleCore = ModuleCore(0xF6a5b7319DfBc84EB94872478be98462aA9Aab99);
        liquidator = Liquidator(0x9700a0ca88BC835E992d819e59029965DBBfb1d6);
        config = CorkConfig(0x190305d34e061F7739CbfaD9fC8e5Ece94C86467);
        flashSwapRouter = 0x8547ac5A696bEB301D5239CdE9F3894B106476C9;

        // Deploy the HedgeUnitFactry contract
        hedgeUnitRouter = new HedgeUnitRouter();
        hedgeUnitFactory =
            new HedgeUnitFactory(address(moduleCore), address(config), flashSwapRouter, address(hedgeUnitRouter));
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
        vm.stopBroadcast();
    }
}
