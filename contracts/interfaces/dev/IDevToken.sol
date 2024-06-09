// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDevToken {
    function mint(address to, uint256 amount) external;

    function burnSelf(uint256 amount) external;
}
