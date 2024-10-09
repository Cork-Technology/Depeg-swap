pragma solidity ^0.8.24;

import {State, VaultState, VaultConfig, VaultWithdrawalPool, VaultAmmLiquidityPool} from "./State.sol";
import {VaultConfigLibrary} from "./VaultConfig.sol";
import {Pair, PairLibrary, Id} from "./Pair.sol";
import {LvAsset, LvAssetLibrary} from "./LvAssetLib.sol";
import {PsmLibrary} from "./PsmLib.sol";
import {PsmRedemptionAssetManager, RedemptionAssetManagerLibrary} from "./RedemptionAssetManagerLib.sol";
import {MathHelper} from "./MathHelper.sol";
import {Guard} from "./Guard.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {VaultPool, VaultPoolLibrary} from "./VaultPoolLib.sol";
import {MinimalUniswapV2Library} from "./uni-v2/UniswapV2Library.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap-v2/RouterV2.sol";
import {IUniswapV2Pair} from "../interfaces/uniswap-v2/pair.sol";
import {DepegSwap, DepegSwapLibrary} from "./DepegSwapLib.sol";
import {Asset, ERC20, ERC20Burnable} from "../core/assets/Asset.sol";
import {ICommon} from "../interfaces/ICommon.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Vault Library Contract
 * @author Cork Team
 * @notice Vault Library implements features for  LVCore(liquidity Vault Core)
 */
library VaultLibrary {
    using VaultConfigLibrary for VaultConfig;
    using PairLibrary for Pair;
    using LvAssetLibrary for LvAsset;
    using PsmLibrary for State;
    using RedemptionAssetManagerLibrary for PsmRedemptionAssetManager;
    using BitMaps for BitMaps.BitMap;
    using DepegSwapLibrary for DepegSwap;
    using VaultPoolLibrary for VaultPool;
    using SafeERC20 for IERC20;

    /// @notice caller is not authorized to perform the action, e.g transfering
    /// redemption rights to another address while not having the rights
    error Unauthorized(address caller);

    /// @notice inssuficient balance to perform expiry redeem(e.g requesting 5 LV to redeem but trying to redeem 10)
    error InsufficientBalance(address caller, uint256 requested, uint256 balance);

    /// @notice insufficient output amount, e.g trying to redeem 100 LV whcih you expect 100 RA but only received 50 RA
    error InsufficientOutputAmount(uint256 amountOutMin, uint256 received);

    // for avoiding stack too deep errors
    struct Tolerance {
        uint256 ra;
        uint256 ct;
    }

    function initialize(VaultState storage self, address lv, uint256 fee, address ra, uint256 initialDsPrice)
        external
    {
        self.config = VaultConfigLibrary.initialize(fee);

        self.lv = LvAssetLibrary.initialize(lv);
        self.balances.ra = RedemptionAssetManagerLibrary.initialize(ra);
        self.initialDsPrice = initialDsPrice;
    }

    function __addLiquidityToAmmUnchecked(
        State storage self,
        uint256 raAmount,
        uint256 ctAmount,
        address raAddress,
        address ctAddress,
        IUniswapV2Router02 ammRouter,
        uint256 raTolerance,
        uint256 ctTolerance
    ) internal {
        IERC20(raAddress).safeIncreaseAllowance(address(ammRouter), raAmount);
        IERC20(ctAddress).safeIncreaseAllowance(address(ammRouter), ctAmount);

        (uint256 raAdded, uint256 ctAdded, uint256 lp) = ammRouter.addLiquidity(
            raAddress, ctAddress, raAmount, ctAmount, raTolerance, ctTolerance, address(this), block.timestamp
        );

        uint256 dustCt = ctAmount - ctAdded;

        if (dustCt > 0) {
            SafeERC20.safeTransfer(IERC20(ctAddress), msg.sender, dustCt);
        }

        uint256 dustRa = raAmount - raAdded;

        if (dustRa > 0) {
            SafeERC20.safeTransfer(IERC20(raAddress), msg.sender, dustRa);
        }
        self.vault.config.lpBalance += lp;
    }

    function _addFlashSwapReserveLv(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        DepegSwap storage ds,
        uint256 amount
    ) internal {
        IERC20(ds._address).safeIncreaseAllowance(address(flashSwapRouter), amount);
        flashSwapRouter.addReserveLv(self.info.toId(), self.globalAssetIdx, amount);
    }

    // MUST be called on every new DS issuance
    function onNewIssuance(
        State storage self,
        uint256 prevDsId,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter,
        uint256 deadline
    ) external {
        // do nothing at first issuance
        if (prevDsId == 0) {
            return;
        }

        if (!self.vault.lpLiquidated.get(prevDsId)) {
            _liquidatedLp(self, prevDsId, ammRouter, flashSwapRouter, deadline);
        }

        __provideAmmLiquidityFromPool(self, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }

    function safeBeforeExpired(State storage self) internal view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
    }

    function safeAfterExpired(State storage self) external view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);
    }

    function __provideLiquidityWithRatio(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        IUniswapV2Router02 ammRouter,
        Tolerance memory tolerance
    ) internal returns (uint256 ra, uint256 ct) {
        (ra, ct) = __calculateProvideLiquidityAmount(self, amount, flashSwapRouter);

        __provideLiquidity(self, ra, ct, flashSwapRouter, ctAddress, ammRouter, tolerance, amount);
    }

    function __calculateProvideLiquidityAmount(State storage self, uint256 amount, IDsFlashSwapCore flashSwapRouter)
        internal
        view
        returns (uint256 ra, uint256 ct)
    {
        uint256 dsId = self.globalAssetIdx;
        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);
        uint256 exchangeRates = self.ds[dsId].exchangeRate();

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amount, ctRatio, exchangeRates);
    }

    function __provideLiquidityWithRatio(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        IUniswapV2Router02 ammRouter
    ) internal returns (uint256 ra, uint256 ct) {
        (uint256 raTolerance, uint256 ctTolerance) =
            MathHelper.calculateWithTolerance(ra, ct, MathHelper.UNIV2_STATIC_TOLERANCE);

        __provideLiquidityWithRatio(
            self, amount, flashSwapRouter, ctAddress, ammRouter, Tolerance(raTolerance, ctTolerance)
        );
    }

    function __getAmmCtPriceRatio(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 dsId)
        internal
        view
        returns (uint256 ratio)
    {
        Id id = self.info.toId();
        uint256 exchangeRate = self.ds[dsId].exchangeRate();
        uint256 hpa = flashSwapRouter.getCurrentEffectiveHPA(id);
        bool isRollover = flashSwapRouter.isRolloverSale(id, dsId);

        uint256 marketRatio;

        try flashSwapRouter.getCurrentPriceRatio(id, dsId) returns (uint256, uint256 _marketRatio) {
            marketRatio = _marketRatio;
        } catch {
            marketRatio = 0;
        }

        ratio = _determineRatio(hpa, marketRatio, self.vault.initialDsPrice, exchangeRate, isRollover, dsId);
    }

    function _determineRatio(
        uint256 hpa,
        uint256 marketRatio,
        uint256 initialDsPrice,
        uint256 exchangeRate,
        bool isRollover,
        uint256 dsId
    ) internal pure returns (uint256 ratio) {
        // fallback to initial ds price ratio if hpa is 0, and market ratio is 0
        // usually happens when there's no trade on the router AND is not the first issuance
        // OR it's the first issuance
        if (hpa == 0 && marketRatio == 0) {
            ratio = exchangeRate - initialDsPrice;
            return ratio;
        }

        // this will return the hpa as ratio when it's basically not the first issuance, and there's actually an hpa to rely on
        // we must specifically check for market ratio since, we want to trigger this only when there's no market ratio(i.e freshly after a rollover)
        if (dsId != 1 && isRollover && hpa != 0 && marketRatio == 0) {
            ratio = exchangeRate - hpa;
            return ratio;
        }

        // this will be the default ratio to use
        if (marketRatio != 0) {
            ratio = marketRatio;
            return ratio;
        }
    }

    function __provideLiquidity(
        State storage self,
        uint256 raAmount,
        uint256 ctAmount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        IUniswapV2Router02 ammRouter,
        Tolerance memory tolerance,
        uint256 amountRaOriginal
    ) internal {
        uint256 dsId = self.globalAssetIdx;

        // no need to provide liquidity if the amount is 0
        if (raAmount == 0 && ctAmount == 0) {
            return;
        }

        PsmLibrary.unsafeIssueToLv(self, MathHelper.calculateProvideLiquidityAmount(amountRaOriginal, raAmount));

        __addLiquidityToAmmUnchecked(
            self, raAmount, ctAmount, self.info.redemptionAsset(), ctAddress, ammRouter, tolerance.ra, tolerance.ct
        );
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[dsId], ctAmount);
    }

    function __provideAmmLiquidityFromPool(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        IUniswapV2Router02 ammRouter
    ) internal {
        uint256 dsId = self.globalAssetIdx;

        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (uint256 ra, uint256 ct, uint256 originalBalance) =
            self.vault.pool.rationedToAmm(ctRatio, self.ds[dsId].exchangeRate());

        // this doesn't really matter tbh, since the amm is fresh and we're the first one to add liquidity to it
        (uint256 raTolerance, uint256 ctTolerance) =
            MathHelper.calculateWithTolerance(ra, ct, MathHelper.UNIV2_STATIC_TOLERANCE);

        __provideLiquidity(
            self, ra, ct, flashSwapRouter, ctAddress, ammRouter, Tolerance(raTolerance, ctTolerance), originalBalance
        );

        self.vault.pool.resetAmmPool();
    }

    function deposit(
        State storage self,
        address from,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter,
        uint256 raTolerance,
        uint256 ctTolerance
    ) external returns (uint256 received) {
        if (amount == 0) {
            revert ICommon.ZeroDeposit();
        }
        safeBeforeExpired(self);

        uint256 exchangeRate;

        // we mint 1:1 if it's the first deposit
        if (!self.vault.initialized) {
            exchangeRate = 1 ether;
            self.vault.initialized = true;
        } else {
            // else we get the current exchange rate of LV
            (exchangeRate,,) = previewRedeemEarly(self, 1 ether, flashSwapRouter);
        }

        self.vault.balances.ra.lockUnchecked(amount, from);
        __provideLiquidityWithRatio(
            self, amount, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter, Tolerance(raTolerance, ctTolerance)
        );

        // then we calculate how much LV we will get for the amount of RA we deposited with the exchange rate
        // this is to seprate the yield vs the actual deposit amount. so when a user withdraws their LV, they get their accrued yield properly
        amount = MathHelper.calculateDepositAmountWithExchangeRate(amount, exchangeRate);

        self.vault.lv.issue(from, amount);

        received = amount;
    }

    // preview a deposit action with current exchange rate,
    // returns the amount of shares(share pool token) that user will receive
    function previewDeposit(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 amount)
        external
        view
        returns (uint256 lvReceived, uint256 raAddedAsLiquidity, uint256 ctAddedAsLiquidity)
    {
        uint256 exchangeRate;

        // we mint 1:1 if it's the first deposit
        if (!self.vault.initialized) {
            exchangeRate = 1 ether;
        } else {
            // else we get the current exchange rate of LV
            (exchangeRate,,) = previewRedeemEarly(self, 1 ether, flashSwapRouter);
        }

        // then we calculate how much LV we will get for the amount of RA we deposited with the exchange rate
        // this is to seprate the yield vs the actual deposit amount. so when a user withdraws their LV, they get their accrued yield properly
        amount = MathHelper.calculateDepositAmountWithExchangeRate(amount, exchangeRate);

        (raAddedAsLiquidity, ctAddedAsLiquidity) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(
            amount,
            __getAmmCtPriceRatio(self, flashSwapRouter, self.globalAssetIdx),
            self.ds[self.globalAssetIdx].exchangeRate()
        );

        lvReceived = amount;
    }

    function __liquidateUnchecked(
        State storage self,
        address raAddress,
        address ctAddress,
        IUniswapV2Router02 ammRouter,
        IUniswapV2Pair ammPair,
        uint256 lp,
        uint256 deadline
    ) internal returns (uint256 raReceived, uint256 ctReceived) {
        ammPair.approve(address(ammRouter), lp);

        // amountAMin & amountBMin = 0 for 100% tolerence
        (raReceived, ctReceived) = ammRouter.removeLiquidity(raAddress, ctAddress, lp, 0, 0, address(this), deadline);

        self.vault.config.lpBalance -= lp;
    }

    // used by early redeem, will liquidate LP partially
    function _liquidateLpPartial(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter,
        uint256 lvRedeemed,
        uint256 deadline
    ) internal returns (uint256 ra) {
        uint256 ammCtBalance;

        (ra, ammCtBalance) = __calculateAndLiquidate(self, dsId, flashSwapRouter, ammRouter, lvRedeemed, deadline);

        ra += _redeemCtDsAndSellExcessCt(self, dsId, ammRouter, flashSwapRouter, ammCtBalance, deadline);
    }

    function __calculateAndLiquidate(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter,
        uint256 lvRedeemed,
        uint256 deadline
    ) private returns (uint256 ra, uint256 ammCtBalance) {
        DepegSwap storage ds = self.ds[dsId];

        uint256 lpliquidated = _calculateLpEquivalent(self, dsId, flashSwapRouter, lvRedeemed);

        (ra, ammCtBalance) = __liquidateUnchecked(
            self, self.info.pair1, ds.ct, ammRouter, IUniswapV2Pair(ds.ammPair), lpliquidated, deadline
        );
    }

    function _calculateLpEquivalent(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        uint256 lvRedeemed
    ) private view returns (uint256 lpRemoved) {
        uint256 raPerLp;
        uint256 raPerLv;

        (raPerLv,, raPerLp,) = __calculateCtBalanceWithRate(self, flashSwapRouter, dsId);
        lpRemoved = MathHelper.convertToLp(raPerLv, raPerLp, lvRedeemed);
    }

    function _redeemCtDsAndSellExcessCt(
        State storage self,
        uint256 dsId,
        IUniswapV2Router02 ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        uint256 ammCtBalance,
        uint256 deadline
    ) internal returns (uint256 ra) {
        uint256 reservedDs = flashSwapRouter.getLvReserve(self.info.toId(), dsId);

        uint256 redeemAmount = reservedDs >= ammCtBalance ? ammCtBalance : reservedDs;

        flashSwapRouter.emptyReservePartialLv(self.info.toId(), dsId, redeemAmount);

        ra += PsmLibrary.lvRedeemRaWithCtDs(self, redeemAmount, dsId);

        // we subtract redeem amount since we already liquidate it from the router
        uint256 ctSellAmount = reservedDs - redeemAmount >= ammCtBalance ? 0 : ammCtBalance - redeemAmount;

        DepegSwap storage ds = self.ds[dsId];
        address[] memory path = new address[](2);
        path[0] = ds.ct;
        path[1] = self.info.pair1;

        if (ctSellAmount != 0) {
            IERC20(ds.ct).safeIncreaseAllowance(address(ammRouter), ctSellAmount);
            // 100% tolerance, to ensure this not fail
            ra += ammRouter.swapExactTokensForTokens(ctSellAmount, 0, path, address(this), deadline)[1];
        }
    }

    function _liquidatedLp(
        State storage self,
        uint256 dsId,
        IUniswapV2Router02 ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        uint256 deadline
    ) internal {
        DepegSwap storage ds = self.ds[dsId];
        uint256 lpBalance = self.vault.config.lpBalance;

        // if there's no LP, then there's nothing to liquidate
        if (lpBalance == 0) {
            return;
        }

        // the following things should happen here(taken directly from the whitepaper) :
        // 1. The AMM LP is redeemed to receive CT + RA
        // 2. Any excess DS in the LV is paired with CT to redeem RA
        // 3. The excess CT is used to claim RA + PA in the PSM
        // 4. End state: Only RA + redeemed PA remains
        self.vault.lpLiquidated.set(dsId);

        (uint256 raAmm, uint256 ctAmm) = __liquidateUnchecked(
            self, self.info.pair1, ds.ct, ammRouter, IUniswapV2Pair(ds.ammPair), lpBalance, deadline
        );

        // avoid stack too deep error
        _pairAndRedeemCtDs(self, flashSwapRouter, dsId, ctAmm, raAmm);
    }

    function _pairAndRedeemCtDs(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        uint256 dsId,
        uint256 ctAmm,
        uint256 raAmm
    ) private returns (uint256 redeemAmount, uint256 ctAttributedToPa) {
        uint256 reservedDs = flashSwapRouter.emptyReserveLv(self.info.toId(), dsId);

        redeemAmount = reservedDs >= ctAmm ? ctAmm : reservedDs;
        redeemAmount = PsmLibrary.lvRedeemRaWithCtDs(self, redeemAmount, dsId);

        // if the reserved DS is more than the CT that's available from liquidating the AMM LP
        // then there's no CT we can use to effectively redeem RA + PA from the PSM
        ctAttributedToPa = reservedDs >= ctAmm ? 0 : ctAmm - reservedDs;

        uint256 psmPa;
        uint256 psmRa;

        if (ctAttributedToPa != 0) {
            (psmPa, psmRa) = PsmLibrary.lvRedeemRaPaWithCt(self, ctAttributedToPa, dsId);
        }

        psmRa += redeemAmount + raAmm;

        self.vault.pool.reserve(self.vault.lv.totalIssued(), psmRa, psmPa);
    }

    function _tryLiquidateLpAndRedeemCtToPsm(State storage self, uint256 dsId, IDsFlashSwapCore flashSwapRouter)
        internal
        view
        returns (uint256 totalRa, uint256 pa)
    {
        uint256 ammCtBalance;

        (totalRa, ammCtBalance) = __calculateTotalRaAndCtBalance(self, flashSwapRouter, dsId);

        uint256 reservedDs = flashSwapRouter.getLvReserve(self.info.toId(), dsId);

        // pair DS and CT to redeem RA
        totalRa += reservedDs > ammCtBalance ? ammCtBalance : reservedDs;

        uint256 raFromCt;
        // redeem CT to get RA + PA
        (pa, raFromCt) = PsmLibrary.previewRedeemWithCt(
            self,
            dsId,
            // CT attributed to PA
            reservedDs > ammCtBalance ? 0 : ammCtBalance - reservedDs
        );
    }

    // duplate function to avoid stack too deep error
    function __calculateTotalRaAndCtBalance(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 dsId)
        internal
        view
        returns (uint256 totalRa, uint256 ammCtBalance)
    {
        IUniswapV2Pair ammPair = flashSwapRouter.getUniV2pair(self.info.toId(), dsId);

        (uint256 raReserve, uint256 ctReserve,) = ammPair.getReserves();

        (raReserve, ctReserve) = MinimalUniswapV2Library.reverseSortWithAmount224(
            ammPair.token0(), ammPair.token1(), self.info.pair1, self.ds[dsId].ct, raReserve, ctReserve
        );

        (,,,, totalRa, ammCtBalance) = __calculateTotalRaAndCtBalanceWithReserve(
            self, raReserve, ctReserve, flashSwapRouter.getUniV2pair(self.info.toId(), dsId).totalSupply()
        );
    }

    // duplate function to avoid stack too deep error
    function __calculateCtBalanceWithRate(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 dsId)
        internal
        view
        returns (uint256 raPerLv, uint256 ctPerLv, uint256 raPerLp, uint256 ctPerLp)
    {
        (uint256 raReserve, uint256 ctReserve,) = flashSwapRouter.getUniV2pair(self.info.toId(), dsId).getReserves();

        (raReserve, ctReserve) = MinimalUniswapV2Library.reverseSortWithAmount224(
            flashSwapRouter.getUniV2pair(self.info.toId(), dsId).token0(),
            flashSwapRouter.getUniV2pair(self.info.toId(), dsId).token1(),
            self.info.pair1,
            self.ds[dsId].ct,
            raReserve,
            ctReserve
        );

        (,, raPerLv, ctPerLv, raPerLp, ctPerLp) = __calculateTotalRaAndCtBalanceWithReserve(
            self, raReserve, ctReserve, flashSwapRouter.getUniV2pair(self.info.toId(), dsId).totalSupply()
        );
    }

    function __calculateTotalRaAndCtBalanceWithReserve(
        State storage self,
        uint256 raReserve,
        uint256 ctReserve,
        uint256 lpSupply
    )
        internal
        view
        returns (
            uint256 totalRa,
            uint256 ammCtBalance,
            uint256 raPerLv,
            uint256 ctPerLv,
            uint256 raPerLp,
            uint256 ctPerLp
        )
    {
        (raPerLv, ctPerLv, raPerLp, ctPerLp, totalRa, ammCtBalance) = MathHelper.calculateLvValueFromUniV2Lp(
            lpSupply, self.vault.config.lpBalance, raReserve, ctReserve, Asset(self.vault.lv._address).totalSupply()
        );
    }

    function _tryLiquidateLpAndSellCtToAmm(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        uint256 lvRedeemed
    ) internal view returns (uint256 totalRa, uint256 lpLiquidated) {
        uint256 lvReserve = flashSwapRouter.getLvReserve(self.info.toId(), dsId);

        (uint256 raPerLv,, uint256 raPerLp,) = __calculateCtBalanceWithRate(self, flashSwapRouter, dsId);

        (uint256 raReserve, uint256 ctReserve) = _getRaCtReserveSorted(self, flashSwapRouter, dsId);

        // calculate how much LP we need to liquidate to redeem the LV
        lpLiquidated = MathHelper.convertToLp(raPerLv, raPerLp, lvRedeemed);

        uint256 lpTotalSupply = flashSwapRouter.getUniV2pair(self.info.toId(), dsId).totalSupply();
        // totalRa we remove
        totalRa = lpLiquidated * raReserve / lpTotalSupply;

        // total Ct we remove
        uint256 ammCtBalance = lpLiquidated * ctReserve / lpTotalSupply;

        // pair DS and CT to redeem RA
        totalRa += lvReserve > ammCtBalance ? ammCtBalance : lvReserve;

        uint256 excessCt = lvReserve > ammCtBalance ? 0 : ammCtBalance - lvReserve;

        totalRa += _trySellCtToAmm(self, dsId, flashSwapRouter, excessCt, lpLiquidated, lpTotalSupply);
    }

    function _getRaCtReserveSorted(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 dsId)
        internal
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        (raReserve, ctReserve,) = flashSwapRouter.getUniV2pair(self.info.toId(), dsId).getReserves();

        (raReserve, ctReserve) = MinimalUniswapV2Library.reverseSortWithAmount224(
            flashSwapRouter.getUniV2pair(self.info.toId(), dsId).token0(),
            flashSwapRouter.getUniV2pair(self.info.toId(), dsId).token1(),
            self.info.pair1,
            self.ds[dsId].ct,
            raReserve,
            ctReserve
        );
    }

    function _trySellCtToAmm(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        uint256 excessCt,
        uint256 lpLiquidated,
        uint256 lpTotalSupply
    ) internal view returns (uint256 ra) {
        if (excessCt == 0) {
            return 0;
        }

        (uint256 raReserve, uint256 ctReserve) = _getRaCtReserveSorted(self, flashSwapRouter, dsId);
        raReserve -= (lpLiquidated * raReserve) / lpTotalSupply;
        ctReserve -= (lpLiquidated * ctReserve) / lpTotalSupply;

        ra = MinimalUniswapV2Library.getAmountOut(excessCt, ctReserve, raReserve);
    }

    // IMPORTANT : only psm, flash swap router and early redeem LV can call this function
    function provideLiquidityWithFee(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter
    ) public {
        __provideLiquidityWithRatio(self, amount, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }
    // taken directly from spec document, technically below is what should happen in this function
    //
    // '#' refers to the total circulation supply of that token.
    // '&' refers to the total amount of token in the LV.
    //
    // say our percent fee is 3%
    // fee(amount)
    //
    // say the amount of user LV token is 'N'
    //
    // AMM LP liquidation (#LP/#LV) provide more CT($CT) + WA($WA) :
    // &CT = &CT + $CT
    // &WA = &WA + $WA
    //
    // Create WA pairing CT with DS inside the vault :
    // &WA = &WA + &(CT + DS)
    //
    // Excess and unpaired CT is sold to AMM to provide WA($WA) :
    // &WA = $WA
    //
    // the LV token rate is :
    // eLV = &WA/#LV
    //
    // redemption amount(rA) :
    // rA = N x eLV
    //
    // final amount(Fa) :
    // Fa = rA - fee(rA)

    function redeemEarly(
        State storage self,
        address owner,
        address receiver,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter,
        bytes memory rawLvPermitSig,
        uint256 permitDeadline,
        uint256 amountOutMin,
        uint256 ammDeadline
    ) external returns (uint256 received, uint256 fee, uint256 feePercentage) {
        safeBeforeExpired(self);
        if (permitDeadline != 0) {
            DepegSwapLibrary.permit(
                self.vault.lv._address, rawLvPermitSig, owner, address(this), amount, permitDeadline
            );
        }

        feePercentage = self.vault.config.fee;

        received = _liquidateLpPartial(self, self.globalAssetIdx, flashSwapRouter, ammRouter, amount, ammDeadline);

        fee = MathHelper.calculatePercentageFee(received, feePercentage);

        if (fee != 0) {
            provideLiquidityWithFee(self, fee, flashSwapRouter, ammRouter);
            received = received - fee;
        }

        if (received < amountOutMin) {
            revert InsufficientOutputAmount(amountOutMin, received);
        }

        ERC20Burnable(self.vault.lv._address).burnFrom(owner, amount);
        self.vault.balances.ra.unlockToUnchecked(received, receiver);
    }

    function previewRedeemEarly(State storage self, uint256 amount, IDsFlashSwapCore flashSwapRouter)
        public
        view
        returns (uint256 received, uint256 fee, uint256 feePercentage)
    {
        safeBeforeExpired(self);

        feePercentage = self.vault.config.fee;

        (received,) = _tryLiquidateLpAndSellCtToAmm(self, self.globalAssetIdx, flashSwapRouter, amount);

        fee = MathHelper.calculatePercentageFee(received, feePercentage);

        received -= fee;
    }
}
