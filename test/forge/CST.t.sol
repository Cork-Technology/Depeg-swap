pragma solidity ^0.8.24;

import "./Helper.sol";
import "./../../contracts/tokens/CST.sol";
import "./../../contracts/tokens/CETH.sol";

contract CSTTEST is Helper {
    CST public cst;
    CETH public ceth;

    function setUp() external {
        ceth = new CETH();
        cst = new CST("Cork Staked Ethereum", "CST", address(ceth), DEFAULT_ADDRESS, 0, 1 ether);
        ceth.grantRole(ceth.MINTER_ROLE(), address(cst));

        ceth.mint(address(this), 10 ether);
    }

    function test_rateIsCorrect() external {
        ceth.approve(address(cst), 10 ether);
        cst.deposit(10 ether);
        vm.assertEq(cst.balanceOf(address(this)), 10 ether);

        vm.prank(DEFAULT_ADDRESS);
        cst.changeRate(2 ether);

        vm.assertEq(ceth.balanceOf(address(cst)), 20 ether);

        cst.approve(address(cst), 1 ether);
        cst.requestWithdrawal(1 ether);
        cst.processWithdrawals(1);

        vm.assertEq(ceth.balanceOf(address(this)), 2 ether);
    }
}
