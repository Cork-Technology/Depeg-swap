// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Id} from "../libraries/Pair.sol";

/**
 * @title ISwapDs Interface
 * @author Cork Team
 * @notice ISwapDs interface for supporting Swapping(Buy/Sell) of DS/CT
 */
interface ISwapDs {
    function buy(Id id, uint256 dsId, uint256 amount) external returns (uint256 received);

    function currentPrice(Id id, uint256 dsId) external view returns (uint256);

    function sell(Id id, uint256 dsId, uint256 amount) external returns (uint256 received);

    function previewSell(Id id, uint256 dsId, uint256 amount) external view returns (uint256 received);

    function previewBuy(Id id, uint256 dsId, uint256 amount) external view returns (uint256 received);
}
