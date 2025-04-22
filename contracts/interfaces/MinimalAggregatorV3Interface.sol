// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @dev Inspired by
/// https://github.com/smartcontractkit/chainlink/blob/master/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol
interface MinimalAggregatorV3Interface {
    /// @notice Returns the precision of the feed.
    function decimals() external view returns (uint8);

    /// @notice Returns Chainlink's `latestRoundData` return values.
    /// @notice Only the `answer` field is used.
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
