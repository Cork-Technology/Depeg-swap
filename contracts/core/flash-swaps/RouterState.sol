// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../libraries/DsFlashSwap.sol";
import "../../libraries/Pair.sol";
import "../../interfaces/IDsFlashSwapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RouterState is
    IDsFlashSwapUtility,
    IDsFlashSwapCore,
    Ownable
{
    using DsFlashSwaplibrary for ReserveState;

    mapping(Id => ReserveState) reserves;

    function onNewIssuance(
        Id reserveId,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve
    ) external override onlyOwner {
        reserves[reserveId].onNewIssuance(dsId, ds, pair, initialReserve);
    }

    function emptyReserve(
        Id reserveId,
        uint256 dsId
    ) external returns (uint256 amount) {
        return reserves[reserveId].emptyReserve(dsId, owner());
    }

    function getCurrentPriceRatio(
        Id id,
        uint256 dsId
    )
        external
        view
        override
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        (raPriceRatio, ctPriceRatio) = reserves[id].getPriceRatio(dsId);
    }

    function addReserve(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external override onlyOwner {
        reserves[id].addReserve(dsId, amount, owner());
    }

    function getState(
        Id id
    ) internal view returns (ReserveState storage reserve) {
        return reserves[id];
    }

    function getCurrentDsPrice(
        Id id,
        uint256 dsId
    ) external view returns (uint256 price) {
        return reserves[id].getCurrentDsPrice(dsId);
    }

    function getAmountIn(
        Id id,
        uint256 dsId,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        return reserves[id].getAmountIn(dsId, amountOut);
    }

    function getAmountOut(
        Id id,
        uint256 dsId,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        return reserves[id].getAmountOut(dsId, amountIn);
    }
}
