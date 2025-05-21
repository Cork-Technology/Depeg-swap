// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @dev From
/// https://github.com/smartcontractkit/chainlink/blob/contracts-v1.3.0/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol
/// https://docs.chain.link/data-feeds/api-reference/#aggregatorv3interface
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
