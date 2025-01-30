pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {ProtectedUnit} from "../../contracts/core/assets/ProtectedUnit.sol";
import {ProtectedUnitFactory} from "../../contracts/core/assets/ProtectedUnitFactory.sol";

contract DeployScript is Script {
    ModuleCore public moduleCore;
    Liquidator public liquidator;
    ProtectedUnitFactory public protectedUnitFactory;
    // TODO : insert this
    address corkConfig = address(0);

    ProtectedUnit public protectedUnitbsETH;
    ProtectedUnit public protectedUnitwamuETH;
    ProtectedUnit public protectedUnitmlETH;
    ProtectedUnit public protectedUnitsvbUSD;
    ProtectedUnit public protectedUnitfedUSD;
    ProtectedUnit public protectedUnitomgUSD;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    address ceth = 0x34505854505A4a4e898569564Fb91e17614e1969;
    address cUSD = 0xEEeA08E6F6F5abC28c821Ffe2035326C6Bfd2017;
    address bsETH = 0x0BAbf92b3e4fd64C26e1F6A05B59a7e0e0708378;
    address wamuETH = 0xd9682A7CE1C48f1de323E9b27A5D0ff0bAA24254;
    address mlETH = 0x98524CaB765Cb0De83F71871c56dc67C202e166d;
    address svbUSD = 0x7AE4c173d473218b59bF8A1479BFC706F28C635b;
    address fedUSD = 0xd8d134BEc26f7ebdAdC2508a403bf04bBC33fc7b;
    address omgUSD = 0x182733031965686043d5196207BeEE1dadEde818;

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
        moduleCore = ModuleCore(0x0e5212A25DDbf4CBEa390199b62C249aBf3637fF);

        console.log("Module Core                     : ", address(moduleCore));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the Liquidator contract
        // liquidator = new Liquidator(corkConfig, hookTrampoline, settlementContract, address(moduleCore));
        // console.log("Liquidator                      : ", address(liquidator));
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // // Deploy the ProtectedUnitFactry contract
        // protectedUnitFactory = new ProtectedUnitFactory(address(moduleCore), address(liquidator));
        // console.log("ProtectedUnit Factory               : ", address(protectedUnitFactory));
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the ProtectedUnit contract
        // protectedUnitwamuETH = ProtectedUnit(
        //     protectedUnitFactory.deployProtectedUnit(
        //         moduleCore.getId(wamuETH, ceth, wamuETHExpiry),
        //         wamuETH,
        //         "Washington Mutual restaked ETH - CETH",
        //         INITIAL_MINT_CAP
        //     )
        // );
        // console.log("HU wamuETH                      : ", address(protectedUnitwamuETH));

        // protectedUnitbsETH = ProtectedUnit(
        //     protectedUnitFactory.deployProtectedUnit(
        //         moduleCore.getId(bsETH, wamuETH, bsETHExpiry),
        //         bsETH,
        //         "Bear Sterns Restaked ETH - Washington Mutual restaked ETH",
        //         INITIAL_MINT_CAP
        //     )
        // );
        // console.log("HU bsETH                        : ", address(protectedUnitbsETH));

        // protectedUnitmlETH = ProtectedUnit(
        //     protectedUnitFactory.deployProtectedUnit(
        //         moduleCore.getId(mlETH, bsETH, mlETHExpiry),
        //         mlETH,
        //         "Merrill Lynch staked ETH - Bear Sterns Restaked ETH",
        //         INITIAL_MINT_CAP
        //     )
        // );
        // console.log("HU mlETH                        : ", address(protectedUnitmlETH));

        // protectedUnitfedUSD = ProtectedUnit(
        //     protectedUnitFactory.deployProtectedUnit(
        //         moduleCore.getId(fedUSD, cUSD, fedUSDExpiry), fedUSD, "Fed Up USD - CUSD", INITIAL_MINT_CAP
        //     )
        // );
        // console.log("HU fedUSD                      : ", address(protectedUnitfedUSD));

        // protectedUnitsvbUSD = ProtectedUnit(
        //     protectedUnitFactory.deployProtectedUnit(
        //         moduleCore.getId(svbUSD, fedUSD, svbUSDExpiry),
        //         svbUSD,
        //         "Sillycoin Valley Bank USD - Fed Up USD",
        //         INITIAL_MINT_CAP
        //     )
        // );
        // console.log("HU svbUSD                      : ", address(protectedUnitsvbUSD));

        // protectedUnitomgUSD = ProtectedUnit(
        //     protectedUnitFactory.deployProtectedUnit(
        //         moduleCore.getId(omgUSD, svbUSD, omgUSDExpiry),
        //         omgUSD,
        //         "Own My Gold USD - Sillycoin Valley Bank USD",
        //         INITIAL_MINT_CAP
        //     )
        // );
        // console.log("HU omgUSD                      : ", address(protectedUnitomgUSD));
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
