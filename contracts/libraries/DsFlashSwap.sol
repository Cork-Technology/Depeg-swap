// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "../interfaces/uniswap-v2/pair.sol";
import "../core/assets/Asset.sol";
import "./DsSwapperMathLib.sol";

struct AssetPair {
    Asset ds;
    /// @dev [RA, CT]
    IUniswapV2Pair pair;
    /// @dev this is the amount that the flash swap router has in reserve
    uint256 reserve;
    /// @dev this represent the amount of DS that the LV has in reserve
    /// will be used to fullfill buy DS orders based on the LV DS selling strategy
    // (i.e 50:50 for first expiry, and 80:20 on subsequent expiries. note that it's represented as LV:AMM)
    uint256 lvReserve;
}
struct ReserveState {
    /// @dev dsId => [RA, CT, DS]
    mapping(uint256 => AssetPair) ds;
}

library DsFlashSwaplibrary {
    function onNewIssuance(
        ReserveState storage self,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve,
        uint256 initialLvReserve
    ) internal {
        self.ds[dsId] = AssetPair(
            Asset(ds),
            IUniswapV2Pair(pair),
            initialReserve,
            initialLvReserve
        );
    }

    function getCurrentDsPrice(
        ReserveState storage self,
        uint256 dsId
    ) internal view returns (uint256 price) {
        (uint112 raReserve, uint112 ctReserve, ) = self
            .ds[dsId]
            .pair
            .getReserves();

        price = SwapperMathLibrary.calculateDsPrice(
            raReserve,
            ctReserve,
            self.ds[dsId].ds.exchangeRate()
        );
    }

    function getAmountIn(
        ReserveState storage self,
        uint256 dsId,
        uint256 amountOut
    ) internal view returns (uint256 amountIn) {
        (uint112 raReserve, uint112 ctReserve, ) = self
            .ds[dsId]
            .pair
            .getReserves();

        amountIn = SwapperMathLibrary.getAmountIn(
            amountOut,
            raReserve,
            ctReserve,
            self.ds[dsId].ds.exchangeRate()
        );
    }

    function getAmountOut(
        ReserveState storage self,
        uint256 dsId,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        (uint112 raReserve, uint112 ctReserve, ) = self
            .ds[dsId]
            .pair
            .getReserves();

        amountOut = SwapperMathLibrary.getAmountOut(
            amountIn,
            raReserve,
            ctReserve,
            self.ds[dsId].ds.exchangeRate()
        );
    }
}
