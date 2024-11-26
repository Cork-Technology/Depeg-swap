pragma solidity ^0.8.24;

interface IWithdrawalRouter {
    struct Tokens {
        address token;
        uint256 amount;
    }

    function route(address receiver, Tokens[] calldata tokens) external;
}
