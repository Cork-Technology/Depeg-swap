pragma solidity ^0.8.24;

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
    address public cUSD = 0xEEeA08E6F6F5abC28c821Ffe2035326C6Bfd2017;

    address bsETH = 0x0BAbf92b3e4fd64C26e1F6A05B59a7e0e0708378;
    uint256 bsETHexpiry = 302400;

    address wamuETH = 0xd9682A7CE1C48f1de323E9b27A5D0ff0bAA24254;
    uint256 wamuETHexpiry = 302400;

    address mlETH = 0x98524CaB765Cb0De83F71871c56dc67C202e166d;
    uint256 mlETHexpiry = 86400;

    address fedUSD = 0xd8d134BEc26f7ebdAdC2508a403bf04bBC33fc7b;
    uint256 fedUSDexpiry = 302400;

    address svbUSD = 0x7AE4c173d473218b59bF8A1479BFC706F28C635b;
    uint256 svbUSDexpiry = 302400;

    address omgUSD = 0x182733031965686043d5196207BeEE1dadEde818;
    uint256 omgUSDexpiry = 43200;

    CETH cETH;

    uint256 depositLVAmt = 10000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        moduleCore = ModuleCore(0x8445a4caD9F5a991E668427dC96A0a6b80ca629b);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        increaseLvDeposit(wamuETH, ceth, 500 ether, wamuETHexpiry);
        increaseLvDeposit(bsETH, wamuETH, 500 ether, bsETHexpiry);
        increaseLvDeposit(mlETH, bsETH, 500 ether, mlETHexpiry);
        increaseLvDeposit(fedUSD, cUSD, 500 ether, fedUSDexpiry);
        increaseLvDeposit(svbUSD, fedUSD, 500 ether, svbUSDexpiry);
        increaseLvDeposit(omgUSD, svbUSD, 500 ether, omgUSDexpiry);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function increaseLvDeposit(address cst, address cETHToken, uint256 liquidityAmt, uint256 expiryPeriod) public {
        Id id = moduleCore.getId(cst, cETHToken, expiryPeriod);
        CETH(cETHToken).approve(address(moduleCore), depositLVAmt);
        moduleCore.depositLv(id, depositLVAmt, 0, 0);
        console.log("LV Deposited");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }
}
