// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "../libraries/Pair.sol";
import "../libraries/DsFlashSwap.sol";

interface IDsFlashSwapUtility {
    function getCurrentDsPrice(
        Id id,
        uint256 dsId
    ) external view returns (uint256 price);

    function getAmountIn(
        Id id,
        uint256 dsId,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    function getAmountOut(
        Id id,
        uint256 dsId,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function getCurrentPriceRatio(
        Id id ,
        uint256 dsId
    ) external view returns (uint256 raPriceRatio, uint256 ctPriceRatio);
}

interface IDsFlashSwapCore {
    function onNewIssuance(
        Id reserveId,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve
    ) external;

    function addReserve(Id id, uint256 dsId, uint256 amount) external;
}
