// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IUniswapV2Pair} from "../interfaces/uniswap-v2/pair.sol";
import {Asset} from "../core/assets/Asset.sol";
import {SwapperMathLibrary} from "./DsSwapperMathLib.sol";
import {MinimalUniswapV2Library} from "./uni-v2/UniswapV2Library.sol";
import {PermitChecker} from "./PermitChecker.sol";
import {ICorkHook} from "../interfaces/UniV4/IMinimalHook.sol";
import "Cork-Hook/lib/MarketSnapshot.sol";
import "./../interfaces/IDsFlashSwapRouter.sol";

/**
 * @dev AssetPair structure for Asset Pairs
 */
struct AssetPair {
    Asset ra;
    Asset ct;
    Asset ds;
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
    bool gradualSale;
}

/**
 * @title DsFlashSwaplibrary Contract
 * @author Cork Team
 * @notice DsFlashSwap library which implements supporting lib and functions flashswap related features for DS/CT
 */
library DsFlashSwaplibrary {
    using MarketSnapshotLib for MarketSnapshot;

    /// @dev the percentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on first issuance
    uint256 public constant INITIAL_RESERVE_SELL_PRESSURE_PERCENTAGE = 50e18;

    /// @dev the percentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on subsequent issuances
    uint256 public constant SUBSEQUENT_RESERVE_SELL_PRESSURE_PERCENTAGE = 80e18;

    uint256 public constant FIRST_ISSUANCE = 1;

    function onNewIssuance(ReserveState storage self, uint256 dsId, address ds, address ra, address ct) internal {
        self.ds[dsId] = AssetPair(Asset(ra), Asset(ct), Asset(ds), 0, 0);

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

    function getPriceRatio(ReserveState storage self, uint256 dsId, ICorkHook router)
        internal
        view
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        AssetPair storage asset = self.ds[dsId];

        (uint256 raReserve, uint256 ctReserve) = router.getReserves(address(asset.ra), address(asset.ct));

        (raPriceRatio, ctPriceRatio) = SwapperMathLibrary.getPriceRatio(raReserve, ctReserve);
    }

    function tryGetPriceRatioAfterSellDs(
        ReserveState storage self,
        uint256 dsId,
        uint256 ctSubstracted,
        uint256 raAdded,
        ICorkHook router
    ) internal view returns (uint256 raPriceRatio, uint256 ctPriceRatio) {
        AssetPair storage asset = self.ds[dsId];

        (uint256 raReserve, uint256 ctReserve) = router.getReserves(address(asset.ra), address(asset.ct));

        raReserve += raAdded;
        ctReserve -= ctSubstracted;

        (raPriceRatio, ctPriceRatio) = SwapperMathLibrary.getPriceRatio(raReserve, ctReserve);
    }

    function getReserve(ReserveState storage self, uint256 dsId, ICorkHook router)
        internal
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        AssetPair storage asset = self.ds[dsId];

        (raReserve, ctReserve) = router.getReserves(address(asset.ra), address(asset.ct));
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

    function getReservesSorted(AssetPair storage self, ICorkHook router)
        internal
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        (raReserve, ctReserve) = router.getReserves(address(self.ra), address(self.ct));
    }

    function getAmountOutSellDS(AssetPair storage assetPair, uint256 amount, ICorkHook router)
        internal
        view
        returns (uint256 amountOut, uint256 repaymentAmount, bool success)
    {
        (uint256 raReserve, uint256 ctReserve) = getReservesSorted(assetPair, router);

        repaymentAmount = router.getAmountIn(address(assetPair.ra), address(assetPair.ct), true, amount);

        (success, amountOut) = SwapperMathLibrary.getAmountOutSellDs(repaymentAmount, amount);
    }

    function getAmountOutBuyDS(
        AssetPair storage assetPair,
        uint256 amount,
        ICorkHook router,
        IDsFlashSwapCore.BuyAprroxParams memory params
    ) internal view returns (uint256 amountOut, uint256 borrowedAmount, uint256 repaymentAmount) {
        (uint256 raReserve, uint256 ctReserve) = getReservesSorted(assetPair, router);

        uint256 issuedAt = assetPair.ds.issuedAt();
        uint256 currentTime = block.timestamp;
        uint256 end = assetPair.ds.expiry();

        amountOut = SwapperMathLibrary.getAmountOutBuyDs(
            uint256(raReserve),
            uint256(ctReserve),
            amount,
            issuedAt,
            end,
            currentTime,
            params.epsilon,
            params.maxApproxIter
        );

        borrowedAmount = amountOut - amount;

        MarketSnapshot memory market = router.getMarketSnapshot(address(assetPair.ra), address(assetPair.ct));
        // reverse linear search for optimal borrow  amount since the math doesn't take into account the fee

        for (uint256 i = 0; i < params.maxApproxIter; i++) {
            repaymentAmount = market.getAmountIn(borrowedAmount, false);

            if (repaymentAmount <= amountOut) {
                return (amountOut, borrowedAmount, repaymentAmount);
            } else {
                borrowedAmount -= params.feeIntervalAdjustment;
                amountOut = borrowedAmount + amount;
            }
        }

        revert("approx exhausted");
    }

    function isRAsupportsPermit(address token) internal view returns (bool) {
        return PermitChecker.supportsPermit(token);
    }
}
