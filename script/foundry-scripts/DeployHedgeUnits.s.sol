pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../contracts/core/Liquidator.sol";
import {HedgeUnit} from "../../contracts/core/assets/HedgeUnit.sol";
import {HedgeUnitFactory} from "../../contracts/core/assets/HedgeUnitFactory.sol";

contract DeployHedgeUnitsScript is Script {
    ModuleCore public moduleCore;
    Liquidator public liquidator;
    HedgeUnitFactory public hedgeUnitFactory;

    HedgeUnit public hedgeUnitbsETH;
    HedgeUnit public hedgeUnitwamuETH;
    HedgeUnit public hedgeUnitmlETH;
    HedgeUnit public hedgeUnitsvbUSD;
    HedgeUnit public hedgeUnitfedUSD;
    HedgeUnit public hedgeUnitomgUSD;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address sender = vm.addr(pk);

    address ceth = 0xD4B903723EbAf1Bf0a2D8373fd5764e050114Dcd;
    address cUSD = 0x8cdd2A328F36601A559c321F0eA224Cc55d9EBAa;
    address bsETH = 0x71710AcACeD2b5Fb608a1371137CC1becFf391E0;
    address wamuETH = 0x212542457f2F50Ab04e74187cE46b79A8B330567;
    address mlETH = 0xc63b0e46FDA3be5c14719257A3EC235499Ca4D33;
    address svbUSD = 0x80bA1d3DF59c62f3C469477C625F4F1D9a1532E6;
    address fedUSD = 0x618134155a3aB48003EC137FF1984f79BaB20028;
    address omgUSD = 0xD8CEF48A9dc21FFe2ef09A7BD247e28e11b5B754;

    uint256 wamuETHExpiry = 3.5 days;
    uint256 bsETHExpiry = 3.5 days;
    uint256 mlETHExpiry = 1 days;
    uint256 svbUSDExpiry = 3.5 days;
    uint256 fedUSDExpiry = 3.5 days;
    uint256 omgUSDExpiry = 0.5 days;

    address settlementContract = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    uint256 constant INITIAL_MINT_CAP = 1000 * 1e18; // 1000 tokens

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        moduleCore = ModuleCore(0x0e5212A25DDbf4CBEa390199b62C249aBf3637fF);

        console.log("Module Core                     : ", address(moduleCore));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the Liquidator contract
        liquidator = new Liquidator(sender, 10000, settlementContract);
        console.log("Liquidator                      : ", address(liquidator));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnitFactry contract
        hedgeUnitFactory = new HedgeUnitFactory(address(moduleCore), address(liquidator));
        hedgeUnitFactory.updateLiquidatorRole(sender, true);
        console.log("HedgeUnit Factory               : ", address(hedgeUnitFactory));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the HedgeUnit contract
        hedgeUnitwamuETH = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(wamuETH, ceth, wamuETHExpiry),
                wamuETH,
                "Washington Mutual restaked ETH - CETH",
                INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitwamuETH), true);
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
        liquidator.updateLiquidatorRole(address(hedgeUnitmlETH), true);
        console.log("HU mlETH                        : ", address(hedgeUnitmlETH));

        hedgeUnitfedUSD = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(fedUSD, cUSD, fedUSDExpiry), fedUSD, "Fed Up USD - CUSD", INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitfedUSD), true);
        console.log("HU fedUSD                       : ", address(hedgeUnitfedUSD));

        hedgeUnitsvbUSD = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(svbUSD, fedUSD, svbUSDExpiry),
                svbUSD,
                "Sillycoin Valley Bank USD - Fed Up USD",
                INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitsvbUSD), true);
        console.log("HU svbUSD                       : ", address(hedgeUnitsvbUSD));

        hedgeUnitomgUSD = HedgeUnit(
            hedgeUnitFactory.deployHedgeUnit(
                moduleCore.getId(omgUSD, svbUSD, omgUSDExpiry),
                omgUSD,
                "Own My Gold USD - Sillycoin Valley Bank USD",
                INITIAL_MINT_CAP
            )
        );
        liquidator.updateLiquidatorRole(address(hedgeUnitomgUSD), true);
        console.log("HU omgUSD                       : ", address(hedgeUnitomgUSD));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
