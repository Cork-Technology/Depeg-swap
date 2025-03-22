// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Helper} from "test/forge/Helper.sol";
import {TransferHelper} from "contracts/libraries/TransferHelper.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
        _mint(msg.sender, 10000 * (10 ** uint256(_decimals)));
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

contract TransferHelperTest is Helper {
    MockERC20 token18;
    MockERC20 token6;
    address user = address(0x123);
    address recipient = address(0x456);

    function setUp() public {
        vm.startPrank(user);

        token18 = new MockERC20("Token18", "TK18", 18);
        token6 = new MockERC20("Token6", "TK6", 6);

        vm.stopPrank();

        // approve all tokens
        token18.approve(user, 1000 * 10 ** 18);
        token6.approve(user, 1000 * 10 ** 6);

        vm.startPrank(user);

        // transfer some tokens to test address
        token18.transfer(address(this), 1000 * 10 ** 18);
        token6.transfer(address(this), 1000 * 10 ** 6);

        token18.approve(address(this), 1000 * 10 ** 18);
        token6.approve(address(this), 1000 * 10 ** 6);
    }

    function test_NormalizeDecimalsUp() public {
        uint256 amount = 1 * 10 ** 6;
        uint256 normalized = TransferHelper.normalizeDecimals(amount, 6, 18);
        vm.assertEq(normalized, 1 * 10 ** 18);
    }

    function test_NormalizeDecimalsDown() public {
        uint256 amount = 1 * 10 ** 18;
        uint256 normalized = TransferHelper.normalizeDecimals(amount, 18, 6);
        vm.assertEq(normalized, 1 * 10 ** 6);
    }

    function test_NormalizeDecimalsNoChange() public {
        uint256 amount = 500 * 10 ** 18;
        uint256 normalized = TransferHelper.normalizeDecimals(amount, 18, 18);
        vm.assertEq(normalized, 500 * 10 ** 18);
    }

    function test_TokenNativeDecimalsToFixed() public {
        uint256 amount = 2 * 10 ** 6;
        uint256 fixedAmount = TransferHelper.tokenNativeDecimalsToFixed(amount, token6);
        vm.assertEq(fixedAmount, 2 * 10 ** 18);
    }

    function test_FixedToTokenNativeDecimals() public {
        uint256 amount = 3 * 10 ** 18;
        uint256 nativeAmount = TransferHelper.fixedToTokenNativeDecimals(amount, token6);
        vm.assertEq(nativeAmount, 3 * 10 ** 6);
    }

    function test_TransferNormalize() public {
        uint256 amount = 4 * 10 ** 18;
        token18.transfer(address(this), amount);
        TransferHelper.transferNormalize(token18, recipient, amount);
        vm.assertEq(token18.balanceOf(recipient), amount);
    }

    function test_TransferNormalizeWithDifferentDecimals() public {
        uint256 amount = 5 * 10 ** 18;
        TransferHelper.transferNormalize(token6, recipient, amount);
        vm.assertEq(token6.balanceOf(recipient), 5 * 10 ** 6);
    }

    function test_TransferFromNormalize() public {
        uint256 amount = 6 * 10 ** 18;

        vm.stopPrank();

        uint256 balanceBefore = token18.balanceOf(address(this));

        TransferHelper.transferFromNormalize(token18, user, amount);

        uint256 balanceAfter = token18.balanceOf(address(this));

        vm.assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_TransferFromNormalizeWithDifferentDecimals() public {
        uint256 amount = 7 * 10 ** 18;

        vm.stopPrank();

        uint256 balanceBefore = token6.balanceOf(address(this));

        TransferHelper.transferFromNormalize(token6, user, amount);

        uint256 balanceAfter = token6.balanceOf(address(this));

        vm.assertEq(balanceAfter, balanceBefore + 7 * 10 ** 6);
    }
}
