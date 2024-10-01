pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ICST {
    function deposit(uint256 amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TransferTokensScript is Script {
    ICST public cst;
    IERC20 public cETH;

    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    uint256 transferAmt = 1_000_000_000 ether;
    address bsETH = 0xcDD25693eb938B3441585eBDB4D766751fd3cdAD;
    address lbETH = 0xA00B0cC70dC182972289a0625D3E1eFCE6Aac624;
    address wamuETH = 0x79A8b67B51be1a9d18Cf88b4e287B46c73316d89;
    address mlETH = 0x68eb9E1bB42feef616BE433b51440D007D86738e;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        cETH = IERC20(ceth);
        transferTokens(0x0000000000000000000000000000000000000000); 
        transferTokens(0x0000000000000000000000000000000000000000); 
        transferTokens(0x0000000000000000000000000000000000000000); 
        transferTokens(0x0000000000000000000000000000000000000000); 
        transferTokens(0x0000000000000000000000000000000000000000); 
        transferTokens(0x0000000000000000000000000000000000000000); 
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function transferTokens(address user) public {
        cETH.transfer(user, transferAmt);

        cst = ICST(bsETH);
        cst.transfer(user, transferAmt);

        cst = ICST(lbETH);
        cst.transfer(user, transferAmt);

        cst = ICST(wamuETH);
        cst.transfer(user, transferAmt);

        cst = ICST(mlETH);
        cst.transfer(user, transferAmt);
    }
}
