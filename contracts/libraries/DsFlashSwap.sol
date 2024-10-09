pragma solidity ^0.8.24;

import {IUniswapV2Pair} from "../interfaces/uniswap-v2/pair.sol";
import {Asset} from "../core/assets/Asset.sol";
import {SwapperMathLibrary} from "./DsSwapperMathLib.sol";
import {MinimalUniswapV2Library} from "./uni-v2/UniswapV2Library.sol";
import {PermitChecker} from "./PermitChecker.sol";

/**
 * @dev AssetPair structure for Asset Pairs
 */
struct AssetPair {
    Asset ra;
    Asset ct;
    Asset ds;
    /// @dev [RA, CT]
    IUniswapV2Pair pair;
    /// @dev this represent the amount of DS that the LV has in reserve
    /// will be used to fullfill buy DS orders based on the LV DS selling strategy
    // (i.e 50:50 for first expiry, and 80:20 on subsequent expiries. note that it's represented as LV:AMM)
    uint256 lvReserve;
    /// @dev this represent the amount of DS that the PSM has in reserve, used to fill buy pressure on rollover period
    /// and  based on the LV DS selling strategy
    uint256 psmReserve;
}

/**
 * @dev ReserveState structure for Reserve
 */
struct ReserveState {
    /// @dev dsId => [RA, CT, DS]
    mapping(uint256 => AssetPair) ds;
    uint256 reserveSellPressurePercentage;
    uint256 hpaCumulated;
    uint256 vhpaCumulated;
    uint256 decayDiscountRateInDays;
    uint256 rolloverEndInBlockNumber;
    uint256 hpa;
}

/**
 * @title DsFlashSwaplibrary Contract
 * @author Cork Team
 * @notice DsFlashSwap library which implements supporting lib and functions flashswap related features for DS/CT
 */
library DsFlashSwaplibrary {
    /// @dev the percentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on first issuance
    uint256 public constant INITIAL_RESERVE_SELL_PRESSURE_PERCENTAGE = 50e18;

    /// @dev the percentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on subsequent issuances
    uint256 public constant SUBSEQUENT_RESERVE_SELL_PRESSURE_PERCENTAGE = 80e18;

    uint256 public constant FIRST_ISSUANCE = 1;

    function onNewIssuance(ReserveState storage self, uint256 dsId, address ds, address pair, address ra, address ct)
        internal
    {
        self.ds[dsId] = AssetPair(Asset(ra), Asset(ct), Asset(ds), IUniswapV2Pair(pair), 0, 0);

        self.reserveSellPressurePercentage = dsId == FIRST_ISSUANCE
            ? INITIAL_RESERVE_SELL_PRESSURE_PERCENTAGE
            : SUBSEQUENT_RESERVE_SELL_PRESSURE_PERCENTAGE;

        if (dsId != FIRST_ISSUANCE) {
            try SwapperMathLibrary.calculateHPA(self.hpaCumulated, self.vhpaCumulated) returns (uint256 hpa) {
                self.hpa = hpa;
            } catch {
                self.hpa = 0;
            }

            self.hpaCumulated = 0;
            self.vhpaCumulated = 0;
        }
    }

    function rolloverSale(ReserveState storage self) internal view returns (bool) {
        return block.number <= self.rolloverEndInBlockNumber;
    }

    function getPair(ReserveState storage self, uint256 dsId) internal view returns (IUniswapV2Pair) {
        return self.ds[dsId].pair;
    }

    function emptyReserveLv(ReserveState storage self, uint256 dsId, address to) internal returns (uint256 emptied) {
        emptied = emptyReservePartialLv(self, dsId, self.ds[dsId].lvReserve, to);
    }

    function getEffectiveHPA(ReserveState storage self) internal view returns (uint256) {
        return self.hpa;
    }

    function getCurrentCumulativeHPA(ReserveState storage self) internal view returns (uint256) {
        try SwapperMathLibrary.calculateHPA(self.hpaCumulated, self.vhpaCumulated) returns (uint256 hpa) {
            return hpa;
        } catch {
            return 0;
        }
    }

    // this function is called for every trade, it recalculates the HPA and VHPA for the reserve.
    function recalculateHPA(ReserveState storage self, uint256 dsId, uint256 ra, uint256 ds) internal {
        uint256 effectiveDsPrice = SwapperMathLibrary.calculateEffectiveDsPrice(ds, ra);
        uint256 issuanceTime = self.ds[dsId].ds.issuedAt();
        uint256 currentTime = block.timestamp;
        uint256 decayDiscount = self.decayDiscountRateInDays;

        self.hpaCumulated +=
            SwapperMathLibrary.calculateHPAcumulated(effectiveDsPrice, ds, decayDiscount, issuanceTime, currentTime);
        self.vhpaCumulated += SwapperMathLibrary.calculateVHPAcumulated(ds, decayDiscount, issuanceTime, currentTime);
    }

    function emptyReservePartialLv(ReserveState storage self, uint256 dsId, uint256 amount, address to)
        internal
        returns (uint256 emptied)
    {
        self.ds[dsId].lvReserve -= amount;
        self.ds[dsId].ds.transfer(to, amount);
        emptied = amount;
    }

    function emptyReservePsm(ReserveState storage self, uint256 dsId, address to) internal returns (uint256 emptied) {
        emptied = emptyReservePartialPsm(self, dsId, self.ds[dsId].psmReserve, to);
    }

    function emptyReservePartialPsm(ReserveState storage self, uint256 dsId, uint256 amount, address to)
        internal
        returns (uint256 emptied)
    {
        self.ds[dsId].psmReserve -= amount;
        self.ds[dsId].ds.transfer(to, amount);
        emptied = amount;
    }

    function getPriceRatio(ReserveState storage self, uint256 dsId)
        internal
        view
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        AssetPair storage asset = self.ds[dsId];

        address token0 = asset.pair.token0();
        address token1 = asset.pair.token1();

        (uint112 token0Reserve, uint112 token1Reserve,) = self.ds[dsId].pair.getReserves();

        (uint112 raReserve, uint112 ctReserve) = MinimalUniswapV2Library.reverseSortWithAmount112(
            token0, token1, address(asset.ra), address(asset.ct), token0Reserve, token1Reserve
        );

        (raPriceRatio, ctPriceRatio) = SwapperMathLibrary.getPriceRatioUniv2(raReserve, ctReserve);
    }

    function tryGetPriceRatioAfterSellDs(
        ReserveState storage self,
        uint256 dsId,
        uint256 ctSubstracted,
        uint256 raAdded
    ) internal view returns (uint256 raPriceRatio, uint256 ctPriceRatio) {
        (uint112 raReserve, uint112 ctReserve) = getReservesSorted(self.ds[dsId]);

        raReserve += uint112(raAdded);
        ctReserve -= uint112(ctSubstracted);

        (raPriceRatio, ctPriceRatio) = SwapperMathLibrary.getPriceRatioUniv2(raReserve, ctReserve);
    }

    function getReserve(ReserveState storage self, uint256 dsId)
        internal
        view
        returns (uint112 raReserve, uint112 ctReserve)
    {
        (raReserve, ctReserve,) = self.ds[dsId].pair.getReserves();
    }

    function addReserveLv(ReserveState storage self, uint256 dsId, uint256 amount, address from)
        internal
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].lvReserve += amount;
        reserve = self.ds[dsId].lvReserve;
    }

    function addReservePsm(ReserveState storage self, uint256 dsId, uint256 amount, address from)
        internal
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].psmReserve += amount;
        reserve = self.ds[dsId].psmReserve;
    }

    function getReservesSorted(AssetPair storage self) internal view returns (uint112 raReserve, uint112 ctReserve) {
        (raReserve, ctReserve,) = self.pair.getReserves();
        (raReserve, ctReserve) = MinimalUniswapV2Library.reverseSortWithAmount112(
            self.pair.token0(), self.pair.token1(), address(self.ra), address(self.ct), raReserve, ctReserve
        );
    }

    function getAmountOutSellDS(AssetPair storage assetPair, uint256 amount)
        internal
        view
        returns (uint256 amountOut, uint256 repaymentAmount, bool success)
    {
        (uint112 raReserve, uint112 ctReserve) = getReservesSorted(assetPair);

        uint256 exchangeRate = assetPair.ds.exchangeRate();
        (success, amountOut, repaymentAmount) =
            SwapperMathLibrary.getAmountOutSellDs(raReserve, ctReserve, amount, exchangeRate);

        if (success) {
            amountOut -= 1;
            repaymentAmount += 1;
        }
    }

    function getAmountOutBuyDS(AssetPair storage assetPair, uint256 amount)
        internal
        view
        returns (uint256 amountOut, uint256 borrowedAmount, uint256 repaymentAmount)
    {
        (uint112 raReserve, uint112 ctReserve) = getReservesSorted(assetPair);
        uint256 exchangeRates = assetPair.ds.exchangeRate();

        (borrowedAmount, amountOut) = SwapperMathLibrary.getAmountOutBuyDs(exchangeRates, raReserve, ctReserve, amount);

        repaymentAmount = amountOut;
    }

    function isRAsupportsPermit(address token) internal view returns (bool) {
        return PermitChecker.supportsPermit(token);
    }
}
