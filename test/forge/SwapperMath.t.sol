pragma solidity ^0.8.24;

import "./../../contracts/libraries/DsSwapperMathLib.sol";
import "forge-std/Test.sol";
import "./../../contracts/libraries/UQ112x112.sol";
import "forge-std/console.sol";
import "./../../contracts/libraries/uni-v2/UniswapV2Library.sol";

// TODO : adjust tests

// contract SwapMathTest is Test {
//     using UQ112x112 for uint224;

//     function test_calculateDecay() external {
//         // 1 %
//         uint256 decayDiscountInDays = 1e18;

//         // together make 1 day worth of discount
//         uint256 issuanceTime = 2 days;
//         uint256 currentTime = 3 days;

//         uint256 discount = SwapperMathLibrary.calculateDecayDiscount(decayDiscountInDays, issuanceTime, currentTime);

//         // exactly 99%
//         vm.assertEq(discount, 99e18);
//     }

//     function test_calculateRolloverSale() external {
//         uint256 lvReserve = 100 ether;
//         uint256 psmReserve = 100 ether;
//         uint256 raProvided = 1 ether;
//         uint256 hpa = 0.1 ether;

//         (
//             uint256 lvProfit,
//             uint256 psmProfit,
//             uint256 raLeft,
//             uint256 dsReceived,
//             uint256 lvReserveUsed,
//             uint256 psmReserveUsed
//         ) = SwapperMathLibrary.calculateRolloverSale(lvReserve, psmReserve, raProvided, hpa);

//         vm.assertEq(lvProfit, 0.5 ether);
//         vm.assertEq(psmProfit, 0.5 ether);
//         vm.assertEq(raLeft, 0 ether);
//         vm.assertEq(dsReceived, 10 ether);
//         vm.assertEq(lvReserveUsed, 5 ether);
//         vm.assertEq(psmReserveUsed, 5 ether);

//         // 25% profit for lv
//         lvReserve = 50 ether;
//         // 75% profit for psm
//         psmReserve = 150 ether;

//         (lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed) =
//             SwapperMathLibrary.calculateRolloverSale(lvReserve, psmReserve, raProvided, hpa);

//         vm.assertEq(lvProfit, 0.25 ether);
//         vm.assertEq(psmProfit, 0.75 ether);
//         vm.assertEq(raLeft, 0 ether);
//         vm.assertEq(dsReceived, 10 ether);
//         vm.assertEq(lvReserveUsed, 2.5 ether);
//         vm.assertEq(psmReserveUsed, 7.5 ether);
//     }

//     function test_calculateVHPAcumulated() external {
//         // 1 %
//         uint256 decayDiscountInDays = 1e18;

//         // together make 50 day worth of discount = 50%
//         uint256 issuanceTime = 50 days;
//         uint256 currentTime = 100 days;
//         uint256 amount = 10 ether;

//         uint256 vhpa = SwapperMathLibrary.calculateVHPAcumulated(amount, decayDiscountInDays, issuanceTime, currentTime);
//         vm.assertEq(vhpa, 5 ether);
//     }

//     function test_calculateHPAcumulated() external {
//         uint256 effectiveDsPrice = 0.1 ether;
//         uint256 amount = 10 ether;
//         // 1 %
//         uint256 decayDiscountInDays = 1e18;

//         // together make 50 day worth of discount = 50%
//         uint256 issuanceTimestamp = 50 days;
//         uint256 currentTime = 100 days;

//         uint256 cumulatedHPA = SwapperMathLibrary.calculateHPAcumulated(
//             effectiveDsPrice, amount, decayDiscountInDays, issuanceTimestamp, currentTime
//         );

//         vm.assertEq(cumulatedHPA, 0.5 ether);
//     }

//     function test_calculateEffecitveDsPrice() external {
//         uint256 dsAmount = 10 ether;
//         uint256 raProvided = 1 ether;

//         uint256 result = SwapperMathLibrary.calculateEffectiveDsPrice(dsAmount, raProvided);

//         vm.assertEq(result, 0.1 ether);
//     }

//     function test_calculateHPA() external {
//         uint256 cumulatedHPA = 1 ether;
//         uint256 cumulatedVHPA = 0.5 ether;

//         uint256 hpa = SwapperMathLibrary.calculateHPA(cumulatedHPA, cumulatedVHPA);

//         vm.assertEq(hpa, 2 ether);
//     }

//     function test_sellDs() external {
//         uint256 ctReserve = 1000 ether;
//         uint256 raReserve = 900 ether;

//         uint256 amountToSell = 5 ether;

//         uint256 borrwedAmount = 4.527164981 ether;

//         (bool success, uint256 raReceived) = SwapperMathLibrary.getAmountOutSellDs(borrwedAmount, amountToSell);

//         vm.assertEq(success, true);
//         vm.assertApproxEqAbs(raReceived, 0.472835019 ether, 0.000001 ether);

//         // can't sell if  CT > RA
//         amountToSell = 4 ether;
//         (success, raReceived) = SwapperMathLibrary.getAmountOutSellDs(borrwedAmount, amountToSell);

//         vm.assertEq(success, false);
//     }

//     function testFuzz_sellDs(uint256 amountToSell, uint256 repaymentAmount) external {
//         vm.assume(amountToSell > repaymentAmount);

//         (bool success, uint256 raReceived) = SwapperMathLibrary.getAmountOutSellDs(repaymentAmount, amountToSell);

//         vm.assertTrue(success);
//     }

//     function test_buyDs() external {
//         uint256 raReserve = 1000 ether;
//         uint256 ctReserve = 1050 ether;

//         uint256 start = 0 days;
//         uint256 end = 100 days;
//         uint256 current = 1 days;

//         uint256 amountToBuy = 0.5 ether;

//         // TODO: verify we have enough CT to repay
//         uint256 returned =
//             SwapperMathLibrary.getAmountOutBuyDs(raReserve, ctReserve, amountToBuy, start, end, current, 1e9, 256);

//         vm.assertApproxEqAbs(returned, 9.0548 ether, 0.001 ether);
//     }
// }
