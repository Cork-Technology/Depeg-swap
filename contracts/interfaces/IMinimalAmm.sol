// SPDX-License-Identifier: UNLICENSED
pragma solidity ^.0 .8 .0;

interface IMinimalAMM {
    function freeWaBalance() returns (uint256);

    function freeCtBalance() returns (uint256);

    function provideLiquidity(uint256 ct, uint256 wa) returns (uint256 lp);

    function liquidateLp(uint256 amout) returns (uint256 ct, uint256 wa);

    function circulatingLp() returns (uint256);
}
