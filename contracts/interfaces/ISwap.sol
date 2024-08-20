// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Id} from "../libraries/Pair.sol";

interface ISwapDs {
    function buy(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external returns (uint256 received);

    function currentPrice(Id id, uint256 dsId) external view returns (uint256);

    function sell(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external returns (uint256 received);

    function previewSell(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 received);

    function previewBuy(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 received);

}
