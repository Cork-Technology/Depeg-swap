pragma solidity ^0.8.24;

import "./Helper.sol";
import "./../../contracts/tokens/CST.sol";
import "./../../contracts/tokens/CETH.sol";

contract CSTTEST is Helper {
    CST public cst;
    CETH public ceth;

    uint256 defaultAmount = 200 ether;

    address secondUser = address(2);

    function setUp() external {
        ceth = new CETH();
        cst = new CST("Cork Staked Ethereum", "CST", address(ceth), DEFAULT_ADDRESS, 0, 0 ether);
        ceth.grantRole(ceth.MINTER_ROLE(), address(cst));

        ceth.mint(secondUser, defaultAmount);
        ceth.mint(address(this), defaultAmount);
    }

    function test_rateIsCorrect() external {
        ceth.approve(address(cst), defaultAmount);
        cst.deposit(defaultAmount);
        vm.assertEq(cst.balanceOf(address(this)), defaultAmount);

        vm.prank(DEFAULT_ADDRESS);
        cst.changeRate(1 ether);

        // vm.assertEq(ceth.balanceOf(address(cst)), defaultAmount);

        // cst.approve(address(cst), defaultAmount);
        // cst.requestWithdrawal(defaultAmount);
        // cst.processWithdrawals(1);

        // vm.assertEq(ceth.balanceOf(address(this)), defaultAmount);

        vm.startPrank(secondUser);

        ceth.approve(address(cst), defaultAmount);
        cst.deposit(defaultAmount);
        vm.assertEq(cst.balanceOf(secondUser), defaultAmount);

        cst.approve(address(cst), defaultAmount);
        cst.requestWithdrawal(defaultAmount);
        cst.processWithdrawals(1);

        vm.assertEq(ceth.balanceOf(secondUser), defaultAmount);
    }
}
