// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IExpiry {
    function isExpired() external view returns (bool);
    function expiry() external view returns (uint256);
}
