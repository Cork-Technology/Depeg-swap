// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Asset} from "../core/assets/Asset.sol";
import {SwapperMathLibrary} from "./DsSwapperMathLib.sol";
import {PermitChecker} from "./PermitChecker.sol";
import {ICorkHook} from "../interfaces/UniV4/IMinimalHook.sol";
import {MarketSnapshot, MarketSnapshotLib} from "Cork-Hook/lib/MarketSnapshot.sol";
import {IDsFlashSwapCore} from "./../interfaces/IDsFlashSwapRouter.sol";
import {TransferHelper} from "./TransferHelper.sol";

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
    uint256 hiyaCumulated;
    uint256 vhiyaCumulated;
    uint256 decayDiscountRateInDays;
    uint256 rolloverEndInBlockNumber;
    uint256 hiya;
    bool gradualSaleDisabled;
}

/**
 * @title DsFlashSwaplibrary Contract, this is meant to be deployed as a library and then linked back into the main contract
 * @author Cork Team
 * @notice DsFlashSwap library which implements supporting lib and functions flashswap related features for DS/CT
 */
library DsFlashSwaplibrary {
    using MarketSnapshotLib for MarketSnapshot;

    uint256 public constant FIRST_ISSUANCE = 1;

    function onNewIssuance(ReserveState storage self, uint256 dsId, address ds, address ra, address ct) external {
        self.ds[dsId] = AssetPair(Asset(ra), Asset(ct), Asset(ds), 0, 0);

        // try to calculate implied ARP, if not present then fallback to the default value provided from previous issuance/start
        if (dsId != FIRST_ISSUANCE) {
            try SwapperMathLibrary.calculateHIYA(self.hiyaCumulated, self.vhiyaCumulated) returns (uint256 hiya) {
                self.hiya = hiya;
            } catch {}

            self.hiyaCumulated = 0;
            self.vhiyaCumulated = 0;
        }
    }

    function rolloverSale(ReserveState storage self) external view returns (bool) {
        return block.number <= self.rolloverEndInBlockNumber;
    }

    function updateReserveSellPressurePercentage(ReserveState storage self, uint256 newPercentage) external {
        // must be between 0.01 and 100
        if (newPercentage < 1e16 || newPercentage > 1e20) {
            revert IDsFlashSwapCore.InvalidParams();
        }

        self.reserveSellPressurePercentage = newPercentage;
    }

    function emptyReserveLv(ReserveState storage self, uint256 dsId, address to) external returns (uint256 emptied) {
        emptied = emptyReservePartialLv(self, dsId, self.ds[dsId].lvReserve, to);
    }

    function getEffectiveHIYA(ReserveState storage self) external view returns (uint256) {
        return self.hiya;
    }

    function getCurrentCumulativeHIYA(ReserveState storage self) external view returns (uint256) {
        try SwapperMathLibrary.calculateHIYA(self.hiyaCumulated, self.vhiyaCumulated) returns (uint256 hiya) {
            return hiya;
        } catch {
            return 0;
        }
    }

    // this function is called for every trade, it recalculates the HIYA and VHIYA for the reserve.
    function recalculateHIYA(ReserveState storage self, uint256 dsId, uint256 ra, uint256 ds) external {
        uint256 start = self.ds[dsId].ds.issuedAt();
        uint256 end = self.ds[dsId].ds.expiry();
        uint256 current = block.timestamp;
        uint256 decayDiscount = self.decayDiscountRateInDays;

        self.hiyaCumulated += SwapperMathLibrary.calcHIYAaccumulated(start, end, current, ds, ra, decayDiscount);
        self.vhiyaCumulated += SwapperMathLibrary.calcVHIYAaccumulated(start, current, decayDiscount, ds);
    }

    function emptyReservePartialLv(ReserveState storage self, uint256 dsId, uint256 amount, address to)
        public
        returns (uint256 emptied)
    {
        self.ds[dsId].lvReserve -= amount;
        self.ds[dsId].ds.transfer(to, amount);
        emptied = amount;
    }

    function emptyReservePsm(ReserveState storage self, uint256 dsId, address to) public returns (uint256 emptied) {
        emptied = emptyReservePartialPsm(self, dsId, self.ds[dsId].psmReserve, to);
    }

    function emptyReservePartialPsm(ReserveState storage self, uint256 dsId, uint256 amount, address to)
        public
        returns (uint256 emptied)
    {
        self.ds[dsId].psmReserve -= amount;
        self.ds[dsId].ds.transfer(to, amount);
        emptied = amount;
    }

    function getPriceRatio(ReserveState storage self, uint256 dsId, ICorkHook router)
        external
        view
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        AssetPair storage asset = self.ds[dsId];

        (uint256 raReserve, uint256 ctReserve) = router.getReserves(address(asset.ra), address(asset.ct));

        raReserve = TransferHelper.tokenNativeDecimalsToFixed(raReserve, asset.ra);
        ctReserve = TransferHelper.tokenNativeDecimalsToFixed(ctReserve, asset.ct);

        (raPriceRatio, ctPriceRatio) = SwapperMathLibrary.getPriceRatio(raReserve, ctReserve);
    }

    function getReserve(ReserveState storage self, uint256 dsId, ICorkHook router)
        external
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        AssetPair storage asset = self.ds[dsId];

        (raReserve, ctReserve) = router.getReserves(address(asset.ra), address(asset.ct));
    }

    function addReserveLv(ReserveState storage self, uint256 dsId, uint256 amount, address from)
        external
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].lvReserve += amount;
        reserve = self.ds[dsId].lvReserve;
    }

    function addReservePsm(ReserveState storage self, uint256 dsId, uint256 amount, address from)
        external
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].psmReserve += amount;
        reserve = self.ds[dsId].psmReserve;
    }

    function getReservesSorted(AssetPair storage self, ICorkHook router)
        public
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        (raReserve, ctReserve) = router.getReserves(address(self.ra), address(self.ct));
    }

    function getAmountOutSellDS(AssetPair storage assetPair, uint256 amount, ICorkHook router)
        external
        view
        returns (uint256 amountOut, uint256 repaymentAmount, bool success)
    {
        repaymentAmount = router.getAmountIn(address(assetPair.ra), address(assetPair.ct), true, amount);

        // this is done in 18 decimals precision
        (success, amountOut) = SwapperMathLibrary.getAmountOutSellDs(
            TransferHelper.tokenNativeDecimalsToFixed(repaymentAmount, assetPair.ra), amount
        );

        // and then we convert it back to the original token decimals
        amountOut = TransferHelper.fixedToTokenNativeDecimals(amountOut, assetPair.ra);
    }

    function getAmountOutBuyDS(
        AssetPair storage assetPair,
        uint256 amount,
        ICorkHook router,
        IDsFlashSwapCore.BuyAprroxParams memory params
    ) external view returns (uint256 amountOut, uint256 borrowedAmount) {
        MarketSnapshot memory market = router.getMarketSnapshot(address(assetPair.ra), address(assetPair.ct));

        market.reserveRa = TransferHelper.tokenNativeDecimalsToFixed(market.reserveRa, assetPair.ra);
        amount = TransferHelper.tokenNativeDecimalsToFixed(amount, assetPair.ra);

        uint256 issuedAt = assetPair.ds.issuedAt();
        uint256 end = assetPair.ds.expiry();

        // this expect 18 decimals both sides
        amountOut = _calculateInitialBuyOut(
            InitialTradeCaclParams(market.reserveRa, market.reserveCt, issuedAt, end, amount, params)
        );

        // we subtract some percentage of it to account for dust imprecisions
        amountOut -= SwapperMathLibrary.calculatePercentage(amountOut, params.precisionBufferPercentage);

        borrowedAmount = amountOut - amount;

        SwapperMathLibrary.OptimalBorrowParams memory optimalParams = SwapperMathLibrary.OptimalBorrowParams(
            market,
            params.maxApproxIter,
            amountOut,
            borrowedAmount,
            amount,
            params.feeIntervalAdjustment,
            params.feeEpsilon
        );

        SwapperMathLibrary.OptimalBorrowResult memory result =
            SwapperMathLibrary.findOptimalBorrowedAmount(optimalParams);

        // result.amountOut = TransferHelper.fixedToTokenNativeDecimals(result.amountOut, assetPair.ra);
        result.borrowedAmount = TransferHelper.fixedToTokenNativeDecimals(result.borrowedAmount, assetPair.ra);

        amountOut = result.amountOut;
        borrowedAmount = result.borrowedAmount;
    }

    struct InitialTradeCaclParams {
        uint256 raReserve;
        uint256 ctReserve;
        uint256 issuedAt;
        uint256 end;
        uint256 amount;
        IDsFlashSwapCore.BuyAprroxParams approx;
    }

    function _calculateInitialBuyOut(InitialTradeCaclParams memory params) public view returns (uint256) {
        return SwapperMathLibrary.getAmountOutBuyDs(
            params.raReserve,
            params.ctReserve,
            params.amount,
            params.issuedAt,
            params.end,
            block.timestamp,
            params.approx.epsilon,
            params.approx.maxApproxIter
        );
    }

    function isRAsupportsPermit(address token) external view returns (bool) {
        return PermitChecker.supportsPermit(token);
    }
}
