pragma solidity 0.8.24;

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
    uint256 reserve;
}

/**
 * @dev ReserveState structure for Reserve    
 */
struct ReserveState {
    /// @dev dsId => [RA, CT, DS]
    mapping(uint256 => AssetPair) ds;
    uint256 reserveSellPressurePrecentage;
}

/**
 * @title DsFlashSwaplibrary Contract
 * @author Cork Team
 * @notice DsFlashSwap library which implements Flashswap related features for DS/CT 
 */
library DsFlashSwaplibrary {
    /// @dev the precentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on first issuance
    uint256 public constant INITIAL_RESERVE_SELL_PRESSURE_PRECENTAGE = 50e18;

    /// @dev the precentage amount of reserve that will be used to fill buy orders
    /// the router will sell in respect to this ratio on subsequent issuances
    uint256 public constant SUBSEQUENT_RESERVE_SELL_PRESSURE_PRECENTAGE = 80e18;

    function onNewIssuance(
        ReserveState storage self,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve,
        address ra,
        address ct
    ) internal {
        self.ds[dsId] = AssetPair(Asset(ra), Asset(ct), Asset(ds), IUniswapV2Pair(pair), initialReserve);

        self.reserveSellPressurePrecentage =
            dsId == 1 ? INITIAL_RESERVE_SELL_PRESSURE_PRECENTAGE : SUBSEQUENT_RESERVE_SELL_PRESSURE_PRECENTAGE;
    }

    function getPair(ReserveState storage self, uint256 dsId) internal view returns (IUniswapV2Pair) {
        return self.ds[dsId].pair;
    }

    function emptyReserve(ReserveState storage self, uint256 dsId, address to) internal returns (uint256 reserve) {
        reserve = emptyReservePartial(self, dsId, self.ds[dsId].reserve, to);
    }

    function emptyReservePartial(ReserveState storage self, uint256 dsId, uint256 amount, address to)
        internal
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transfer(to, amount);

        self.ds[dsId].reserve -= amount;
        reserve = self.ds[dsId].reserve;
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
        AssetPair storage asset = self.ds[dsId];

        address token0 = asset.pair.token0();
        address token1 = asset.pair.token1();

        (uint112 token0Reserve, uint112 token1Reserve,) = self.ds[dsId].pair.getReserves();

        (uint112 raReserve, uint112 ctReserve) = MinimalUniswapV2Library.reverseSortWithAmount112(
            token0, token1, address(asset.ra), address(asset.ct), token0Reserve, token1Reserve
        );

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

    function addReserve(ReserveState storage self, uint256 dsId, uint256 amount, address from)
        internal
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].reserve += amount;
        reserve = self.ds[dsId].reserve;
    }

    function getReservesSorted(AssetPair storage self) internal view returns (uint112 raReserve, uint112 ctReserve) {
        (raReserve, ctReserve,) = self.pair.getReserves();
        (raReserve, ctReserve) = MinimalUniswapV2Library.reverseSortWithAmount112(
            self.pair.token0(), self.pair.token1(), address(self.ra), address(self.ct), raReserve, ctReserve
        );
    }

    function getAmountIn(ReserveState storage self, uint256 dsId, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        (uint112 raReserve, uint112 ctReserve,) = self.ds[dsId].pair.getReserves();

        amountIn = SwapperMathLibrary.getAmountIn(amountOut, raReserve, ctReserve, self.ds[dsId].ds.exchangeRate());
    }

    function getAmountOutSellDS(AssetPair storage assetPair, uint256 amount)
        internal
        view
        returns (uint256 amountOut, uint256 repaymentAmount)
    {
        (uint112 raReserve, uint112 ctReserve) = getReservesSorted(assetPair);
        // we calculate the repayment amount based on the imbalanced ct reserve since we borrow CT from the AMM
        repaymentAmount = MinimalUniswapV2Library.getAmountIn(amount, raReserve, ctReserve - amount);

        // the amountOut is essentially what the user receive, we can calculate this by simply subtracting the repayment amount
        // from the amount, since we're getting back the same RA amount as DS user buy, this works. to get the effective price per DS,
        // you would devide this by the DS amount user bought.
        // note that we subtract 1 to enforce uni v2 rules
        amountOut = amount - repaymentAmount;

        // enforce uni v2 rules, pay 1 wei more
        amountOut -= 1;
        repaymentAmount += 1;

        assert(amountOut + repaymentAmount == amount);
    }

    function getAmountOutBuyDS(AssetPair storage assetPair, uint256 amount)
        internal
        view
        returns (uint256 amountOut, uint256 borrowedAmount, uint256 repaymentAmount)
    {
        (uint112 raReserve, uint112 ctReserve) = getReservesSorted(assetPair);

        (borrowedAmount, amountOut) =
            SwapperMathLibrary.getAmountOutDs(int256(uint256(raReserve)), int256(uint256(ctReserve)), int256(amount));

        repaymentAmount = MinimalUniswapV2Library.getAmountIn(borrowedAmount, ctReserve, raReserve - borrowedAmount);
    }

    function isRAsupportsPermit(address token) internal view returns (bool) {
        return PermitChecker.supportsPermit(token);
    }
}
