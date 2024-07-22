// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../libraries/DsFlashSwap.sol";
import "../../libraries/Pair.sol";

abstract contract RouterState {
    using DsFlashSwaplibrary for ReserveState;

    mapping(Id => ReserveState) reserves;

    function onNewIssuance(
        Id reserveId,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve,
        uint256 initialLvReserve
    ) internal {
        reserves[reserveId].onNewIssuance(
            dsId,
            ds,
            pair,
            initialReserve,
            initialLvReserve
        );
    }

    function getState(
        Id id
    ) internal view returns (ReserveState storage reserve) {
        return reserves[id];
    }

    function getCurrentDsPrice(
        Id id,
        uint256 dsId
    ) internal view returns (uint256 price) {
        return reserves[id].getCurrentDsPrice(dsId);
    }

    function getAmountIn(
        Id id,
        uint256 dsId,
        uint256 amountOut
    ) internal view returns (uint256 amountIn) {
        return reserves[id].getAmountIn(dsId, amountOut);
    }

    function getAmountOut(
        Id id,
        uint256 dsId,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        return reserves[id].getAmountOut(dsId, amountIn);
    }
}
