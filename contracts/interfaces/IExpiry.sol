// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

/**
 * @title IExpiry Interface
 * @author Cork Team
 * @notice IExpiry interface for Expiry contract
 */
interface IExpiry is IErrors {
    /// @notice returns true if the asset is expired
    function isExpired() external view returns (bool);

    ///@notice returns the expiry timestamp if 0 then it means it never expires
    function expiry() external view returns (uint256);

    ///@notice returns the timestamp when the asset was issued
    function issuedAt() external view returns (uint256);
}
