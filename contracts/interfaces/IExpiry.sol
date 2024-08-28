pragma solidity 0.8.24;

/**
 * @title IExpiry Interface
 * @author Cork Team
 * @notice IExpiry interface for Expiry contract
 */
interface IExpiry {
    /// @notice Trying to issue an expired asset
    error Expired();

    function isExpired() external view returns (bool);

    ///@notice returns the expiry timestamp if 0 then it means it never expires
    function expiry() external view returns (uint256);
}
