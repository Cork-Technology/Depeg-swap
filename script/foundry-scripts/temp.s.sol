pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CETH} from "../../contracts/tokens/CETH.sol";
import {CST} from "../../contracts/tokens/CST.sol";
import {Id} from "../../contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ICST {
    function deposit(uint256 amount) external;
}

contract TempScript is Script {
    bool public isProd = vm.envBool("PRODUCTION");
    uint256 public base_redemption_fee = vm.envUint("PSM_BASE_REDEMPTION_FEE_PRECENTAGE");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    uint256 public pk2 = vm.envUint("PRIVATE_KEY2");
    uint256 public pk3 = vm.envUint("PRIVATE_KEY3");

    address user1=0x8e6dd65c50b57fD5935788Dc24d3E954Cd8fc019;
    address user2=0xFFB6b6896D469798cE64136fd3129979411B5514;
    address user3=0xBa66992bE4816Cc3877dA86fA982A93a6948dde9;

    address bsETH = 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9;
    address lbETH = 0xF24177162B1604e56EB338dd9775d75CC79DaC2B;
    address wamuETH = 0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B;
    address mlETH = 0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6;

    CETH cETH = CETH(ceth);

    uint256 depositLVAmt = 40_000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        cETH = new CETH();
        cETH.mint(user1, 100_000_000_000_000 ether);
        cETH.transfer(user2, 200 ether);
        cETH.transfer(user3, 200 ether);
        ceth = address(cETH);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        console.log("CETH                            : ", address(cETH)); // solhint-disable-line no-console

        CST bsETHCST = new CST("Bear Sterns Restaked ETH", "bsETH", ceth, msg.sender, 480 hours, 1 ether);
        bsETH = address(bsETHCST);
        cETH.addMinter(bsETH);
        cETH.approve(bsETH, 500_000 ether);
        bsETHCST.deposit(500_000 ether);
        console.log("bsETH                           : ", address(bsETH)); // solhint-disable-line no-console

        CST lbETHCST = new CST("Lehman Brothers Restaked ETH", "lbETH", ceth, msg.sender, 10 hours, 1 ether);
        lbETH = address(lbETHCST);
        cETH.addMinter(lbETH);
        cETH.approve(lbETH, 500_000 ether);
        lbETHCST.deposit(500_000 ether);
        console.log("lbETH                           : ", address(lbETH)); // solhint-disable-line no-console

        CST wamuETHCST = new CST("Washington Mutual restaked ETH", "wamuETH", ceth, msg.sender, 1 seconds, 1 ether);
        wamuETH = address(wamuETHCST);
        cETH.addMinter(wamuETH);
        cETH.approve(wamuETH, 1_000_000 ether);
        wamuETHCST.deposit(1_000_000 ether);
        console.log("wamuETH                         : ", address(wamuETH)); // solhint-disable-line no-console

        CST mlETHCST = new CST("Merrill Lynch staked ETH", "mlETH", ceth, msg.sender, 5 hours, 1 ether);
        mlETH = address(mlETHCST);
        cETH.addMinter(mlETH);
        cETH.approve(mlETH, 10_000_000 ether);
        mlETHCST.deposit(10_000_000 ether);
        console.log("mlETH                           : ", address(mlETH)); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        cETH = CETH(ceth);
        vm.stopBroadcast();

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        console.log("cETH of user 1                  : ", cETH.balanceOf(user1)); // solhint-disable-line no-console
        console.log("cETH of user 2                  : ", cETH.balanceOf(user2)); // solhint-disable-line no-console
        console.log("cETH of user 3                  : ", cETH.balanceOf(user3)); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console

        vm.startBroadcast(pk2);
        cETH.approve(wamuETH, 200 ether);
        wamuETHCST.deposit(200 ether);
        vm.stopBroadcast();
        console.log("user2 deposited 200 cETH to wamuETH"); // solhint-disable-line no-console
        console.log("user2 wamuETH                  : ", wamuETHCST.balanceOf(user2)); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console

        vm.startBroadcast(pk3);
        cETH.approve(wamuETH, 200 ether);
        wamuETHCST.deposit(200 ether);
        vm.stopBroadcast();
        console.log("user3 deposited 200 cETH to wamuETH"); // solhint-disable-line no-console
        console.log("user3 wamuETH                  : ", wamuETHCST.balanceOf(user3)); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console

        console.log("cETH of user 1                  : ", cETH.balanceOf(user1)); // solhint-disable-line no-console
        console.log("cETH of user 2                  : ", cETH.balanceOf(user2)); // solhint-disable-line no-console
        console.log("cETH of user 3                  : ", cETH.balanceOf(user3)); // solhint-disable-line no-console
        console.log("wamuETH Total Supply            : ", wamuETHCST.totalSupply()); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        vm.startBroadcast(pk2);
        uint256 user2WamuETH = wamuETHCST.balanceOf(user2);
        wamuETHCST.requestWithdrawal(user2WamuETH);
        console.log("user2 requested wamu withdrawal : ", user2WamuETH); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        vm.stopBroadcast();

        vm.startBroadcast(pk3);
        uint256 user3WamuETH = wamuETHCST.balanceOf(user3);
        wamuETHCST.requestWithdrawal(user3WamuETH);
        console.log("user3 requested wamu withdrawal : ", user3WamuETH); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        vm.warp(block.timestamp + 2);
        console.log("moved time for passing withdrawal delay"); // solhint-disable-line no-console
        vm.stopBroadcast();

        vm.startBroadcast(pk);
        wamuETHCST.processWithdrawals(1);
        console.log("Processes user2 withdrawal by backend"); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        console.log("user2 remaining wamuETH         : ", wamuETHCST.balanceOf(user2)); // solhint-disable-line no-console
        console.log("cETH of user 2                  : ", cETH.balanceOf(user2)); // solhint-disable-line no-console
        console.log("user3 remaining wamuETH         : ", wamuETHCST.balanceOf(user3)); // solhint-disable-line no-console
        console.log("cETH of user 3                  : ", cETH.balanceOf(user3)); // solhint-disable-line no-console
        console.log("wamuETH Total Supply            : ", wamuETHCST.totalSupply()); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console

        wamuETHCST.processWithdrawals(1);
        console.log("Processes user3 withdrawal by backend"); // solhint-disable-line no-console
        console.log("user2 remaining wamuETH         : ", wamuETHCST.balanceOf(user2)); // solhint-disable-line no-console
        console.log("cETH of user 2                  : ", cETH.balanceOf(user2)); // solhint-disable-line no-console
        console.log("user3 remaining wamuETH         : ", wamuETHCST.balanceOf(user3)); // solhint-disable-line no-console
        console.log("cETH of user 3                  : ", cETH.balanceOf(user3)); // solhint-disable-line no-console
        console.log("wamuETH Total Supply            : ", wamuETHCST.totalSupply()); // solhint-disable-line no-console
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"); // solhint-disable-line no-console
        vm.stopBroadcast();

        vm.startBroadcast(pk3);
        vm.stopBroadcast();

        vm.startBroadcast(pk3);
        vm.stopBroadcast();

        vm.startBroadcast(pk3);
        vm.stopBroadcast();

        vm.startBroadcast(pk3);
        vm.stopBroadcast();
    }
}
