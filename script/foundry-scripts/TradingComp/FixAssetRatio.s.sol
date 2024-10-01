pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CETH} from "../../../contracts/tokens/CETH.sol";
import {CST} from "../../../contracts/tokens/CST.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FixAssetRatioScript is Script {
    bool public isProd = vm.envBool("PRODUCTION");
    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    uint256 public pk2 = vm.envUint("PRIVATE_KEY2");
    uint256 public pk3 = vm.envUint("PRIVATE_KEY3");

    uint256 public constant HOURS_IN_YEAR = 288; // 12 days * 24 hours(counted 1 day as 1 month)
    uint256 public constant precision = 1e18; // Precision scaling factor

    address user1 = 0x8e6dd65c50b57fD5935788Dc24d3E954Cd8fc019;
    address user2 = 0xFFB6b6896D469798cE64136fd3129979411B5514;
    address user3 = 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9;

    address bsETH = 0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9;
    address lbETH = 0xF24177162B1604e56EB338dd9775d75CC79DaC2B;
    address wamuETH = 0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B;
    address mlETH = 0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6;

    uint256 bsETHDeployedTimestamp = 1726654200;
    uint256 lbETHDeployedTimestamp = 1726654212;
    uint256 wamuETHDeployedTimestamp = 1726654212;
    uint256 mlETHDeployedTimestamp = 1726654212;

    uint256 bsETHYearlyYieldRate = 7.5 ether; // Representing 7.5% scaled by 1e18
    uint256 lbETHYearlyYieldRate = 7.5 ether; // Representing 7.5% scaled by 1e18
    uint256 wamuETHYearlyYieldRate = 3 ether; // Representing 3.0% scaled by 1e18
    uint256 mlETHYearlyYieldRate = 7.5 ether; // Representing 7.5% scaled by 1e18

    CETH cETH = CETH(ceth);

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk3);
        CST bsETHCST = CST(bsETH);
        console.log("total bsETH Supply                       : ", bsETHCST.totalSupply());
        console.log("cETH in bsETH Before                     : ", cETH.balanceOf(bsETH));
        bsETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total bsETH Supply                       : ", bsETHCST.totalSupply());
        console.log("cETH in bsETH After                      : ", cETH.balanceOf(bsETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        uint256 cETHToBeTransferred =
            calculateInterest(bsETHDeployedTimestamp, bsETHYearlyYieldRate, bsETHCST.totalSupply());
        cETH.transfer(bsETH, cETHToBeTransferred);
        console.log("Added Yield up to last hour");
        console.log("total bsETH Supply                       : ", bsETHCST.totalSupply());
        console.log("cETH in bsETH After                      : ", cETH.balanceOf(bsETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        CST lbETHCST = CST(lbETH);
        console.log("total lbETH Supply                       : ", lbETHCST.totalSupply());
        console.log("cETH in lbETH Before                     : ", cETH.balanceOf(lbETH));
        lbETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total lbETH Supply                       : ", lbETHCST.totalSupply());
        console.log("cETH in lbETH After                      : ", cETH.balanceOf(lbETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        cETHToBeTransferred = calculateInterest(lbETHDeployedTimestamp, lbETHYearlyYieldRate, lbETHCST.totalSupply());
        cETH.transfer(lbETH, cETHToBeTransferred);
        console.log("Added Yield up to last hour");
        console.log("total lbETH Supply                       : ", lbETHCST.totalSupply());
        console.log("cETH in lbETH After                      : ", cETH.balanceOf(lbETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        CST wamuETHCST = CST(wamuETH);
        console.log("total wamuETH Supply                       : ", wamuETHCST.totalSupply());
        console.log("cETH in wamuETH Before                     : ", cETH.balanceOf(wamuETH));
        wamuETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total wamuETH Supply                       : ", wamuETHCST.totalSupply());
        console.log("cETH in wamuETH After                      : ", cETH.balanceOf(wamuETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        cETHToBeTransferred =
            calculateInterest(wamuETHDeployedTimestamp, wamuETHYearlyYieldRate, wamuETHCST.totalSupply());
        cETH.transfer(wamuETH, cETHToBeTransferred);
        console.log("Added Yield up to last hour");
        console.log("total wamuETH Supply                       : ", wamuETHCST.totalSupply());
        console.log("cETH in wamuETH After                      : ", cETH.balanceOf(wamuETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        CST mlETHCST = CST(mlETH);
        console.log("total mlETH Supply                       : ", mlETHCST.totalSupply());
        console.log("cETH in mlETH Before                     : ", cETH.balanceOf(mlETH));
        mlETHCST.changeRate(1 ether);
        console.log("Updated Asset Pegging Ratio");
        console.log("total mlETH Supply                       : ", mlETHCST.totalSupply());
        console.log("cETH in mlETH After                      : ", cETH.balanceOf(mlETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        cETHToBeTransferred = calculateInterest(mlETHDeployedTimestamp, mlETHYearlyYieldRate, mlETHCST.totalSupply());
        cETH.transfer(mlETH, cETHToBeTransferred);
        console.log("Added Yield up to last hour");
        console.log("total mlETH Supply                       : ", mlETHCST.totalSupply());
        console.log("cETH in mlETH After                      : ", cETH.balanceOf(mlETH));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function calculateInterest(uint256 deployedTimestamp, uint256 yearlyInterestRate, uint256 totalSupply)
        public
        view
        returns (uint256)
    {
        // Calculate the number of complete hours since deployment - ignoring last partial hour because backend yield streaming is working hourly
        uint256 hoursPassed = (block.timestamp - deployedTimestamp) / 3600;
        console.log(hoursPassed);

        // Calculate the hourly interest rate: yearlyInterestRate / HOURS_IN_YEAR
        // We multiply by precision (1e18) first, to preserve accuracy during division
        uint256 hourlyInterestRate = (yearlyInterestRate * precision) / HOURS_IN_YEAR; // hourlyInterestRate in 1e18*1e18
        console.log(hourlyInterestRate);

        // Calculate the interest based on the elapsed time, interest rate, and total supply
        uint256 rawYield = hoursPassed * hourlyInterestRate / precision;
        uint256 percentageAmount = (totalSupply * rawYield) / 1e20; // This gives the amount based on hourlyInterestRate
        console.log(rawYield);
        console.log(percentageAmount);
        console.log(totalSupply);
        return percentageAmount;
    }
}
