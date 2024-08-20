// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IExpiry {
    /// @notice Trying to issue an expired asset
    error Expired();

    function isExpired() external view returns (bool);

    ///@notice returns the expiry timestamp if 0 then it means it never expires
    function expiry() external view returns (uint256);
}
