// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "../interfaces/uniswap-v2/pair.sol";
import "../core/assets/Asset.sol";
import "./DsSwapperMathLib.sol";

struct AssetPair {
    Asset ra;
    Asset ct;
    Asset ds;
    /// @dev [RA, CT]
    IUniswapV2Pair pair;
    /// @dev this represent the amount of DS that the LV has in reserve
    /// will be used to fullfill buy DS orders based on the LV DS selling strategy
    // (i.e 50:50 for first expiry, and 80:20 on subsequent expiries. note that it's represented as LV:AMM)
    uint256 reserve;
}
struct ReserveState {
    /// @dev dsId => [RA, CT, DS]
    mapping(uint256 => AssetPair) ds;
    uint256 reserveSellPressurePrecentage;
}

library DsFlashSwaplibrary {
    /// @dev the precentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on first issuance
    uint256 public constant INITIAL_RESERVE_SELL_PRESSURE_PRECENTAGE = 501e8;

    /// @dev the precentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on subsequent issuances
    uint256 public constant SUBSEQUENT_RESERVE_SELL_PRESSURE_PRECENTAGE = 801e8;

    function onNewIssuance(
        ReserveState storage self,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve,
        address ra,
        address ct
    ) internal {
        self.ds[dsId] = AssetPair(
            Asset(ra),
            Asset(ct),
            Asset(ds),
            IUniswapV2Pair(pair),
            initialReserve
        );

        self.reserveSellPressurePrecentage = dsId == 1
            ? INITIAL_RESERVE_SELL_PRESSURE_PRECENTAGE
            : SUBSEQUENT_RESERVE_SELL_PRESSURE_PRECENTAGE;
    }

    function getPair(
        ReserveState storage self,
        uint256 dsId
    ) internal view returns (IUniswapV2Pair) {
        return self.ds[dsId].pair;
    }

    function emptyReserve(
        ReserveState storage self,
        uint256 dsId,
        address to
    ) internal returns (uint256 reserve) {
        reserve = emptyReservePartial(self, dsId, self.ds[dsId].reserve, to);
    }

    function emptyReservePartial(
        ReserveState storage self,
        uint256 dsId,
        uint256 amount,
        address to
    ) internal returns (uint256 reserve) {
        self.ds[dsId].ds.transfer(to, amount);

        self.ds[dsId].reserve -= amount;
        reserve = self.ds[dsId].reserve;
    }

    function getPriceRatio(
        ReserveState storage self,
        uint256 dsId
    ) internal view returns (uint256 raPriceRatio, uint256 ctPriceRatio) {
        (uint112 raReserve, uint112 ctReserve, ) = self
            .ds[dsId]
            .pair
            .getReserves();

        (raPriceRatio, ctPriceRatio) = SwapperMathLibrary.getPriceRatioUniv2(
            raReserve,
            ctReserve
        );
    }

    function getReserve(
        ReserveState storage self,
        uint256 dsId
    ) internal view returns (uint112 raReserve, uint112 ctReserve) {
        (raReserve, ctReserve, ) = self.ds[dsId].pair.getReserves();
    }

    function addReserve(
        ReserveState storage self,
        uint256 dsId,
        uint256 amount,
        address from
    ) internal returns (uint256 reserve) {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].reserve += amount;
        reserve = self.ds[dsId].reserve;
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

    function getCurrentDsPriceAfterSellDs(
        ReserveState storage self,
        uint256 dsId,
        uint256 addedRa,
        uint256 subtractedCt
    ) internal view returns (uint256 price) {
        (uint112 raReserve, uint112 ctReserve, ) = self
            .ds[dsId]
            .pair
            .getReserves();

        raReserve += uint112(addedRa);
        ctReserve -= uint112(subtractedCt);

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
