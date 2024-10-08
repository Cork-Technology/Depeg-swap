pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ModuleCore} from "../../contracts/core/ModuleCore.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";

contract IncreaseDepositScript is Script {
    ModuleCore public moduleCore;

    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    address bsETH = 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9;
    address lbETH = 0xF24177162B1604e56EB338dd9775d75CC79DaC2B;
    address wamuETH = 0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B;
    address mlETH = 0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6;

    CETH cETH = CETH(ceth);

    uint256 depositLVAmt = 1_000_000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        cETH = CETH(ceth);

        moduleCore = ModuleCore(0xe56565c208d0a8Ca28FB632aD7F6518f273B8B9f);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        increaseLvDeposit(mlETH, 300_000 ether);
        increaseLvDeposit(lbETH, 300_000 ether);
        increaseLvDeposit(bsETH, 300_000 ether);
        increaseLvDeposit(wamuETH, 500_000 ether);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function increaseLvDeposit(address cst, uint256 liquidityAmt) public {
        Id id = moduleCore.getId(cst, ceth);
        cETH.approve(address(moduleCore), depositLVAmt);
        moduleCore.depositLv(id, depositLVAmt, 0, 0);
        console.log("LV Deposited");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
