// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {MinimalAggregatorV3Interface} from "../interfaces/MinimalAggregatorV3Interface.sol";
import {IExpiry} from "../interfaces/IExpiry.sol";

contract LinearDiscountOracle is MinimalAggregatorV3Interface {
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant ONE = 1e18;

    address public immutable CT;
    uint256 public immutable MATURITY;
    uint256 public immutable BASE_DISCOUNT_PER_YEAR; // 100% = 1e18

    /// @notice Thrown when the discount is invalid.
    error InvalidDiscount();
    /// @notice Thrown when the discount overflows.
    error DiscountOverflow();
    /// @notice Thrown when the contract is initialized with a zero address.
    error ZeroAddress();

    constructor(address _ct, uint256 _baseDiscountPerYear) {
        if (_baseDiscountPerYear > ONE) revert InvalidDiscount();
        if (_ct == address(0)) revert ZeroAddress();

        CT = _ct;
        MATURITY = IExpiry(CT).expiry();
        BASE_DISCOUNT_PER_YEAR = _baseDiscountPerYear;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        uint256 timeLeft = (MATURITY > block.timestamp) ? MATURITY - block.timestamp : 0;
        uint256 discount = getDiscount(timeLeft);

        if (discount > ONE) revert DiscountOverflow();

        return (0, int256(ONE - discount), 0, 0, 0);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function getDiscount(uint256 timeLeft) public view returns (uint256) {
        return (timeLeft * BASE_DISCOUNT_PER_YEAR) / SECONDS_PER_YEAR;
    }
}
