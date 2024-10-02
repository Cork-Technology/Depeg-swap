pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CETH} from "../../../contracts/tokens/CETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SlashCETHScript is Script {
    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PERCENTAGE");
    address public ceth = 0x93D16d90490d812ca6fBFD29E8eF3B31495d257D;
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    address bsETH = 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9;

    CETH cETH = CETH(ceth);

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        cETH = CETH(ceth);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("cETH in bsETH Before                     : ", cETH.balanceOf(bsETH));
        slashUsersCETH(bsETH, cETH.balanceOf(bsETH));
        console.log("cETH in bsETH After                      : ", cETH.balanceOf(bsETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function slashUsersCETH(address user, uint256 amount) public {
        cETH.burn(address(user), amount);
        console.log("cETH slashed for user                    : ", user);
    }
}
