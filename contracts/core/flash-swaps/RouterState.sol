// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../libraries/DsFlashSwap.sol";
import "../../libraries/Pair.sol";
import "../../interfaces/IDsFlashSwapRouter.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RouterState is
    IDsFlashSwapUtility,
    IDsFlashSwapCore,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using DsFlashSwaplibrary for ReserveState;

    constructor() {}

    function initialize(address moduleCore) external initializer notDelegated {
        __Ownable_init(moduleCore);
        __UUPSUpgradeable_init();
    }

    mapping(Id => ReserveState) reserves;

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner notDelegated {}

    function onNewIssuance(
        Id reserveId,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve
    ) external override onlyOwner {
        reserves[reserveId].onNewIssuance(dsId, ds, pair, initialReserve);
    }

    function getAmmReserve(
        Id id,
        uint256 dsId
    ) external view override returns (uint112 raReserve, uint112 ctReserve) {
        (raReserve, ctReserve) = reserves[id].getReserve(dsId);
    }

    function getLvReserve(
        Id id,
        uint256 dsId
    ) external view override returns (uint256 lvReserve) {
        return reserves[id].ds[dsId].reserve;
    }

    function getUniV2pair(
        Id id,
        uint256 dsId
    ) external view override returns (IUniswapV2Pair pair) {
        return reserves[id].getPair(dsId);
    }

    function emptyReserve(
        Id reserveId,
        uint256 dsId
    ) external override onlyOwner returns (uint256 amount) {
        return reserves[reserveId].emptyReserve(dsId, owner());
    }

    function emptyReservePartial(
        Id reserveId,
        uint256 dsId,
        uint256 amount
    ) external override onlyOwner returns (uint256 reserve) {
        return reserves[reserveId].emptyReservePartial(dsId, amount, owner());
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
