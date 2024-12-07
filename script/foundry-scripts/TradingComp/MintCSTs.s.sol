pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {CETH} from "../../../contracts/tokens/CETH.sol";
import {CUSD} from "../../../contracts/tokens/CUSD.sol";
import {CST} from "../../../contracts/tokens/CST.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MintScript is Script {
    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = vm.envAddress("WETH");
    address public cusd = vm.envAddress("CUSD");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address sender = vm.addr(pk);

    address wamuETH = 0x22222228802B45325E0b8D0152C633449Ab06913;
    address bsETH = 0x33333335a697843FDd47D599680Ccb91837F59aF;
    address mlETH = 0x44444447386435500C5a06B167269f42FA4ae8d4;
    address svbUSD = 0x5555555eBBf30a4b084078319Da2348fD7B9e470;
    address fedUSD = 0x666666685C211074C1b0cFed7e43E1e7D8749E43;
    address omgUSD = 0x7777777707136263F82775e7ED0Fc99Bbe6f5eB0;

    uint256 constant INITIAL_MINT_CAP = 10_000_000_000 ether; // 10 billion tokens

    CETH cETH = CETH(ceth);
    CUSD cUSD = CUSD(cusd);

    function run() public {
        vm.startBroadcast(pk);
        CST wamuETHCST = CST(wamuETH);
        cETH.approve(wamuETH, INITIAL_MINT_CAP);
        wamuETHCST.deposit(INITIAL_MINT_CAP);
        console.log("wamuETH                         : ", address(wamuETH));

        CST bsETHCST = CST(bsETH);
        cETH.approve(bsETH, INITIAL_MINT_CAP);
        bsETHCST.deposit(INITIAL_MINT_CAP);
        console.log("bsETH                           : ", address(bsETH));

        CST mlETHCST = CST(mlETH);
        cETH.approve(mlETH, INITIAL_MINT_CAP);
        mlETHCST.deposit(INITIAL_MINT_CAP);
        console.log("mlETH                           : ", address(mlETH));

        CST svbUSDCST = CST(svbUSD);
        cUSD.approve(svbUSD, INITIAL_MINT_CAP);
        svbUSDCST.deposit(INITIAL_MINT_CAP);
        console.log("svbUSD                          : ", address(svbUSD));

        CST fedUSDCST = CST(fedUSD);
        cUSD.approve(fedUSD, INITIAL_MINT_CAP);
        fedUSDCST.deposit(INITIAL_MINT_CAP);
        console.log("fedUSD                          : ", address(fedUSD));

        CST omgUSDCST = CST(omgUSD);
        cUSD.approve(omgUSD, INITIAL_MINT_CAP);
        omgUSDCST.deposit(INITIAL_MINT_CAP);
        console.log("omgUSD                          : ", address(omgUSD));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
