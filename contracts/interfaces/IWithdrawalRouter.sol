// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IWithdrawalRouter {
    struct Tokens {
        address token;
        uint256 amount;
    }

    function route(address receiver, Tokens[] calldata tokens, bytes calldata routerData) external;
}
