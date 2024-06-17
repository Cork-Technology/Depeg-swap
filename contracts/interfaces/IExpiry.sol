// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IExpiry  {
    function isExpired() external view returns (bool);

    ///@notice returns the expiry timestamp if 0 then it means it never expires
    function expiry() external view returns (uint256);
}
