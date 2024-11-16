// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title IRates Interface
 * @author Cork Team
 * @notice IRates interface for providing excahngeRate functions
 */
interface IRates {
    /// @notice returns the exchange rate, if 0 then it means that there's no rate associated with it, like the case of LV token
    function exchangeRate() external view returns (uint256 rates);

    function updateRate(uint256 newRate) external;
}
