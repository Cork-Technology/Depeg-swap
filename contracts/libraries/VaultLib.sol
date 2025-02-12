// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {State, VaultState, VaultConfig, NavCircuitBreaker} from "./State.sol";
import {Pair, PairLibrary, Id} from "./Pair.sol";
import {LvAsset, LvAssetLibrary} from "./LvAssetLib.sol";
import {PsmLibrary} from "./PsmLib.sol";
import {RedemptionAssetManager, RedemptionAssetManagerLibrary} from "./RedemptionAssetManagerLib.sol";
import {MathHelper} from "./MathHelper.sol";
import {Guard} from "./Guard.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {VaultPool, VaultPoolLibrary} from "./VaultPoolLib.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {DepegSwap, DepegSwapLibrary} from "./DepegSwapLib.sol";
import {Asset, ERC20Burnable} from "../core/assets/Asset.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "../interfaces/IVault.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {LiquidityToken} from "Cork-Hook/LiquidityToken.sol";
import {MarketSnapshot} from "Cork-Hook/lib/MarketSnapshot.sol";
import {IWithdrawalRouter} from "./../interfaces/IWithdrawalRouter.sol";
import {TransferHelper} from "./TransferHelper.sol";
import {NavCircuitBreakerLibrary} from "./NavCircuitBreaker.sol";
import {VaultBalanceLibrary} from "./VaultBalancesLib.sol";

/**
 * @title Vault Library Contract
 * @author Cork Team
 * @notice Vault Library implements features for  LVCore(liquidity Vault Core)
 */
library VaultLibrary {
    using PairLibrary for Pair;
    using LvAssetLibrary for LvAsset;
    using PsmLibrary for State;
    using RedemptionAssetManagerLibrary for RedemptionAssetManager;
    using BitMaps for BitMaps.BitMap;
    using DepegSwapLibrary for DepegSwap;
    using VaultPoolLibrary for VaultPool;
    using SafeERC20 for IERC20;
    using VaultBalanceLibrary for State;
    using NavCircuitBreakerLibrary for NavCircuitBreaker;

    // for avoiding stack too deep errors
    struct Tolerance {
        uint256 ra;
        uint256 ct;
    }

    function initialize(VaultState storage self, address lv, address ra, uint256 initialArp) external {
        self.lv = LvAssetLibrary.initialize(lv);
        self.balances.ra = RedemptionAssetManagerLibrary.initialize(ra);
    }

    function __addLiquidityToAmmUnchecked(
        uint256 raAmount,
        uint256 ctAmount,
        address raAddress,
        address ctAddress,
        ICorkHook ammRouter,
        uint256 raTolerance,
        uint256 ctTolerance
    ) internal returns (uint256 lp, uint256 dust) {
        IERC20(raAddress).safeIncreaseAllowance(address(ammRouter), raAmount);
        IERC20(ctAddress).safeIncreaseAllowance(address(ammRouter), ctAmount);

        uint256 raAdded;
        uint256 ctAdded;

        (raAdded, ctAdded, lp) =
            ammRouter.addLiquidity(raAddress, ctAddress, raAmount, ctAmount, raTolerance, ctTolerance, block.timestamp);

        uint256 dustCt = ctAmount - ctAdded;

        if (dustCt > 0) {
            SafeERC20.safeTransfer(IERC20(ctAddress), msg.sender, dustCt);
        }

        uint256 dustRa = raAmount - raAdded;

        if (dustRa > 0) {
            SafeERC20.safeTransfer(IERC20(raAddress), msg.sender, dustRa);
        }
        dust = dustRa + dustCt;
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
        ICorkHook ammRouter,
        uint256 deadline
    ) external {
        // do nothing at first issuance
        if (prevDsId == 0) {
            return;
        }

        // do nothing if there's no LV token minted(no liquidity to act anything)
        if (self.vault.lv.totalIssued() == 0) {
            return;
        }

        _liquidateIfExpired(self, prevDsId, ammRouter, deadline);
        __provideAmmLiquidityFromPool(self, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }

    function _liquidateIfExpired(State storage self, uint256 dsId, ICorkHook ammRouter, uint256 deadline) internal {
        DepegSwap storage ds = self.ds[dsId];
        // we don't want to revert here for easier control flow, expiry check should happen at contract level not library level
        if (!ds.isExpired()) {
            return;
        }
        if (!self.vault.lpLiquidated.get(dsId)) {
            _liquidatedLp(self, dsId, ammRouter, deadline);
            _redeemCtStrategy(self, dsId);
            _takeRaSnapshot(self, dsId);
            _pauseDepositIfPaIsPresent(self);
        }
    }

    function _takeRaSnapshot(State storage self, uint256 dsId) internal {
        self.vault.totalRaSnapshot[dsId] = self.vault.pool.ammLiquidityPool.balance;
    }

    function _pauseDepositIfPaIsPresent(State storage self) internal {
        if (self.vault.pool.withdrawalPool.paBalance > 0) {
            self.vault.config.isDepositPaused = true;
        }
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

    function __provideLiquidityWithRatioGetLP(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook ammRouter,
        Tolerance memory tolerance
    ) internal returns (uint256 ra, uint256 ct, uint256 lp) {
        (ra, ct) = __calculateProvideLiquidityAmount(self, amount, flashSwapRouter);
        (lp,) = __provideLiquidity(self, ra, ct, flashSwapRouter, ctAddress, ammRouter, tolerance, amount);
    }

    // Duplicate function of __provideLiquidityWithRatioGetLP to avoid stack too deep error
    function __provideLiquidityWithRatioGetDust(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook ammRouter,
        Tolerance memory tolerance
    ) internal returns (uint256 ra, uint256 ct, uint256 dust) {
        (ra, ct) = __calculateProvideLiquidityAmount(self, amount, flashSwapRouter);
        (, dust) = __provideLiquidity(self, ra, ct, flashSwapRouter, ctAddress, ammRouter, tolerance, amount);
    }

    function __calculateProvideLiquidityAmount(State storage self, uint256 amount, IDsFlashSwapCore flashSwapRouter)
        internal
        view
        returns (uint256 ra, uint256 ct)
    {
        uint256 dsId = self.globalAssetIdx;
        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amount, ctRatio);
    }

    function __provideLiquidityWithRatio(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook ammRouter
    ) internal returns (uint256 ra, uint256 ct, uint256 dust) {
        (uint256 raTolerance, uint256 ctTolerance) =
            MathHelper.calculateWithTolerance(ra, ct, MathHelper.UNI_STATIC_TOLERANCE);

        (ra, ct, dust) = __provideLiquidityWithRatioGetDust(
            self, amount, flashSwapRouter, ctAddress, ammRouter, Tolerance(raTolerance, ctTolerance)
        );
    }

    function __getAmmCtPriceRatio(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 dsId)
        internal
        view
        returns (uint256 ratio)
    {
        Id id = self.info.toId();
        uint256 hpa = flashSwapRouter.getCurrentEffectiveHIYA(id);
        bool isRollover = flashSwapRouter.isRolloverSale(id);

        // slither-disable-next-line uninitialized-local
        uint256 marketRatio;

        try flashSwapRouter.getCurrentPriceRatio(id, dsId) returns (uint256, uint256 _marketRatio) {
            marketRatio = _marketRatio;
        } catch {
            marketRatio = 0;
        }

        ratio = _determineRatio(hpa, marketRatio, self.info.initialArp, isRollover, dsId);
    }

    function _determineRatio(uint256 hiya, uint256 marketRatio, uint256 initialArp, bool isRollover, uint256 dsId)
        internal
        pure
        returns (uint256 ratio)
    {
        // fallback to initial ds price ratio if hpa is 0, and market ratio is 0
        // usually happens when there's no trade on the router AND is not the first issuance
        // OR it's the first issuance
        if (hiya == 0 && marketRatio == 0) {
            ratio = MathHelper.calculateInitialCtRatio(initialArp);
            return ratio;
        }

        // this will return the hiya as hpa as ratio when it's basically not the first issuance, and there's actually an hiya to rely on
        // we must specifically check for market ratio since, we want to trigger this only when there's no market ratio(i.e freshly after a rollover)
        if (dsId != 1 && isRollover && hiya != 0 && marketRatio == 0) {
            // we add 2 zerom since the function will normalize it to 0-1 from 1-100
            ratio = MathHelper.calculateInitialCtRatio(hiya * 100);
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
        ICorkHook ammRouter,
        Tolerance memory tolerance,
        uint256 amountRaOriginal
    ) internal returns (uint256 lp, uint256 dust) {
        uint256 dsId = self.globalAssetIdx;

        address ra = self.info.ra;
        // no need to provide liquidity if the amount is 0
        if (raAmount == 0 || ctAmount == 0) {
            if (raAmount != 0) {
                SafeERC20.safeTransfer(IERC20(ra), msg.sender, raAmount);
            }

            if (ctAmount != 0) {
                SafeERC20.safeTransfer(IERC20(ctAddress), msg.sender, ctAmount);
            }

            return (0, 0);
        }

        // we use the returned value here since the amount is already normalized
        ctAmount =
            PsmLibrary.unsafeIssueToLv(self, MathHelper.calculateProvideLiquidityAmount(amountRaOriginal, raAmount));

        (lp, dust) =
            __addLiquidityToAmmUnchecked(raAmount, ctAmount, ra, ctAddress, ammRouter, tolerance.ra, tolerance.ct);
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[dsId], ctAmount);

        self.addLpBalance(lp);
    }

    function __provideAmmLiquidityFromPool(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook ammRouter
    ) internal returns (uint256 dust) {
        uint256 dsId = self.globalAssetIdx;

        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (uint256 ra, uint256 ct, uint256 originalBalance) = self.vault.pool.rationedToAmm(ctRatio);

        // this doesn't really matter tbh, since the amm is fresh and we're the first one to add liquidity to it
        (uint256 raTolerance, uint256 ctTolerance) =
            MathHelper.calculateWithTolerance(ra, ct, MathHelper.UNI_STATIC_TOLERANCE);

        (, dust) = __provideLiquidity(
            self, ra, ct, flashSwapRouter, ctAddress, ammRouter, Tolerance(raTolerance, ctTolerance), originalBalance
        );

        self.vault.pool.resetAmmPool();
    }

    function deposit(
        State storage self,
        address from,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook ammRouter,
        uint256 raTolerance,
        uint256 ctTolerance
    ) external returns (uint256 received) {
        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }
        safeBeforeExpired(self);

        self.vault.balances.ra.lockUnchecked(amount, from);

        // split the RA first according to the lv strategy
        (uint256 remaining, uint256 splitted) = _splitCtWithStrategy(self, flashSwapRouter, amount);

        uint256 dsId = self.globalAssetIdx;

        address ct = self.ds[dsId].ct;

        // we mint 1:1 if it's the first deposit, else we mint based on current vault NAV
        if (!self.vault.initialized) {
            // we don't allow depositing less than 1e10 normalized to ensure good initialization
            if (amount < TransferHelper.fixedToTokenNativeDecimals(1e10, self.info.ra)) {
                revert IErrors.InvalidAmount();
            }

            // we use the initial amount as the received amount on first issuance
            // this is important to normalize to 18 decimals since without it
            // the lv share pricing will ehave as though the lv decimals is the same as the ra
            received = TransferHelper.tokenNativeDecimalsToFixed(amount, self.info.ra);
            self.vault.initialized = true;

            __provideLiquidityWithRatioGetLP(
                self, remaining, flashSwapRouter, ct, ammRouter, Tolerance(raTolerance, ctTolerance)
            );
            self.vault.lv.issue(from, received);

            _updateNavCircuitBreakerOnFirstDeposit(self, flashSwapRouter, ammRouter, dsId);

            return received;
        }

        // we used the initial deposit amount to accurately calculate the NAV per share
        received = _calculateReceivedDeposit(
            self,
            ammRouter,
            CalculateReceivedDepositParams({
                ctSplitted: splitted,
                dsId: dsId,
                amount: amount,
                flashSwapRouter: flashSwapRouter
            })
        );

        __provideLiquidityWithRatioGetLP(
            self, remaining, flashSwapRouter, ct, ammRouter, Tolerance(raTolerance, ctTolerance)
        );

        self.vault.lv.issue(from, received);
    }

    struct CalculateReceivedDepositParams {
        uint256 ctSplitted;
        uint256 dsId;
        uint256 amount;
        IDsFlashSwapCore flashSwapRouter;
    }

    function _calculateReceivedDeposit(
        State storage self,
        ICorkHook ammRouter,
        CalculateReceivedDepositParams memory params
    ) internal returns (uint256 received) {
        Id id = self.info.toId();
        address ct = self.ds[params.dsId].ct;

        MarketSnapshot memory snapshot = ammRouter.getMarketSnapshot(self.info.ra, ct);
        uint256 lpSupply = IERC20(snapshot.liquidityToken).totalSupply();
        uint256 vaultLp = self.lpBalance();

        // we convert ra reserve to 18 decimals to get accurate results
        snapshot.reserveRa = TransferHelper.tokenNativeDecimalsToFixed(snapshot.reserveRa, self.info.ra);
        params.amount = TransferHelper.tokenNativeDecimalsToFixed(params.amount, self.info.ra);

        MathHelper.NavParams memory navParams = MathHelper.NavParams({
            reserveRa: snapshot.reserveRa,
            reserveCt: snapshot.reserveCt,
            oneMinusT: snapshot.oneMinusT,
            lpSupply: lpSupply,
            lvSupply: Asset(self.vault.lv._address).totalSupply(),
            // we already split the CT so we need to subtract it first here
            vaultCt: self.vault.balances.ctBalance - params.ctSplitted,
            // subtract the added DS in the flash swap router
            vaultDs: params.flashSwapRouter.getLvReserve(id, params.dsId) - params.ctSplitted,
            vaultLp: vaultLp,
            vaultIdleRa: TransferHelper.tokenNativeDecimalsToFixed(self.vault.balances.ra.locked, self.info.ra)
        });

        uint256 nav = MathHelper.calculateNav(navParams);

        uint256 lvSupply = Asset(self.vault.lv._address).totalSupply();
        received = MathHelper.calculateDepositLv(nav, params.amount, lvSupply);

        // update nav reference for the circuit breaker
        self.vault.config.navCircuitBreaker.validateAndUpdateDeposit(nav);
    }

    function updateCtHeldPercentage(State storage self, uint256 ctHeldPercentage) external {
        // must be between 0% and 100%
        if (ctHeldPercentage >= 100 ether) {
            revert IErrors.InvalidParams();
        }

        self.vault.ctHeldPercetage = ctHeldPercentage;
    }

    function _splitCt(State storage self, uint256 amount) internal view returns (uint256 splitted) {
        uint256 ctHeldPercentage = self.vault.ctHeldPercetage;
        splitted = MathHelper.calculatePercentageFee(ctHeldPercentage, amount);
    }

    // return the amount left and the CT splitted(in 18 decimals)
    function _splitCtWithStrategy(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 amount)
        internal
        returns (uint256 amountLeft, uint256 splitted)
    {
        splitted = _splitCt(self, amount);

        amountLeft = amount - splitted;

        // actually mint ct & ds to vault and used the normalized value
        splitted = PsmLibrary.unsafeIssueToLv(self, splitted);

        // increase the ct balance in the vault
        self.vault.balances.ctBalance += splitted;

        // add ds to flash swap reserve
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[self.globalAssetIdx], splitted);
    }

    // redeem CT that's been held in the pool, must only be called after liquidating LP on new issuance
    function _redeemCtStrategy(State storage self, uint256 dsId) internal {
        uint256 attributedCt = self.vault.balances.ctBalance;

        // reset the ct balance
        self.vault.balances.ctBalance = 0;

        // redeem the ct to the PSM
        (uint256 accruedPa, uint256 accruedRa) = PsmLibrary.lvRedeemRaPaWithCt(self, attributedCt, dsId);

        // add the accrued RA to the amm pool
        self.vault.pool.ammLiquidityPool.balance += accruedRa;

        // add the accrued PA to the withdrawal pool
        self.vault.pool.withdrawalPool.paBalance += accruedPa;
    }

    function __liquidateUnchecked(
        State storage self,
        address raAddress,
        address ctAddress,
        ICorkHook ammRouter,
        uint256 lp,
        uint256 deadline
    ) internal returns (uint256 raReceived, uint256 ctReceived) {
        IERC20(ammRouter.getLiquidityToken(raAddress, ctAddress)).approve(address(ammRouter), lp);

        // amountAMin & amountBMin = 0 for 100% tolerence
        (raReceived, ctReceived) = ammRouter.removeLiquidity(raAddress, ctAddress, lp, 0, 0, deadline);

        self.subtractLpBalance(lp);
    }

    function _liquidatedLp(State storage self, uint256 dsId, ICorkHook ammRouter, uint256 deadline) internal {
        DepegSwap storage ds = self.ds[dsId];
        uint256 lpBalance = self.lpBalance();

        // if there's no LP, then there's nothing to liquidate
        if (lpBalance == 0) {
            self.vault.lpLiquidated.set(dsId);
            return;
        }

        // the following things should happen here(taken directly from the whitepaper) :
        // 1. The AMM LP is redeemed to receive CT + RA
        // 2. Any excess DS in the LV is paired with CT to redeem RA
        // 3. The excess CT is used to claim RA + PA in the PSM
        // 4. End state: Only RA + redeemed PA remains
        self.vault.lpLiquidated.set(dsId);

        (uint256 raAmm, uint256 ctAmm) = __liquidateUnchecked(self, self.info.ra, ds.ct, ammRouter, lpBalance, deadline);

        // avoid stack too deep error
        _redeemCtVault(self, dsId, ctAmm, raAmm);
    }

    function _redeemCtVault(State storage self, uint256 dsId, uint256 ctAmm, uint256 raAmm) internal {
        uint256 psmPa;
        uint256 psmRa;

        (psmPa, psmRa) = PsmLibrary.lvRedeemRaPaWithCt(self, ctAmm, dsId);

        psmRa += raAmm;

        self.vault.pool.reserve(self.vault.lv.totalIssued(), psmRa, psmPa);
    }

    function __calculateTotalRaAndCtBalanceWithReserve(
        State storage self,
        uint256 raReserve,
        uint256 ctReserve,
        uint256 lpSupply,
        uint256 lpBalance
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
        (raPerLv, ctPerLv, raPerLp, ctPerLp, totalRa, ammCtBalance) = MathHelper.calculateLvValueFromUniLp(
            lpSupply, lpBalance, raReserve, ctReserve, Asset(self.vault.lv._address).totalSupply()
        );
    }

    // IMPORTANT : only psm, flash swap router can call this function
    function allocateFeesToVault(State storage self, uint256 amount) public {
        self.vault.balances.ra.incLocked(amount);
    }

    function _calculateSpotNav(State storage self, IDsFlashSwapCore flashSwapRouter, ICorkHook ammRouter, uint256 dsId)
        internal
        returns (uint256 nav)
    {
        Id id = self.info.toId();
        address ct = self.ds[dsId].ct;

        MarketSnapshot memory snapshot = ammRouter.getMarketSnapshot(self.info.ra, ct);
        uint256 lpSupply = IERC20(snapshot.liquidityToken).totalSupply();
        uint256 vaultLp = self.lpBalance();

        // we convert ra reserve to 18 decimals to get accurate results
        snapshot.reserveRa = TransferHelper.tokenNativeDecimalsToFixed(snapshot.reserveRa, self.info.ra);

        MathHelper.NavParams memory navParams = MathHelper.NavParams({
            reserveRa: snapshot.reserveRa,
            reserveCt: snapshot.reserveCt,
            oneMinusT: snapshot.oneMinusT,
            lpSupply: lpSupply,
            lvSupply: Asset(self.vault.lv._address).totalSupply(),
            vaultCt: self.vault.balances.ctBalance,
            vaultDs: flashSwapRouter.getLvReserve(id, dsId),
            vaultLp: vaultLp,
            vaultIdleRa: TransferHelper.tokenNativeDecimalsToFixed(self.vault.balances.ra.locked, self.info.ra)
        });

        nav = MathHelper.calculateNav(navParams);
    }

    function _updateNavCircuitBreakerOnWithdrawal(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook ammRouter,
        uint256 dsId
    ) internal {
        uint256 nav = _calculateSpotNav(self, flashSwapRouter, ammRouter, dsId);
        self.vault.config.navCircuitBreaker.updateOnWithdrawal(nav);
    }

    function _updateNavCircuitBreakerOnFirstDeposit(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook ammRouter,
        uint256 dsId
    ) internal {
        forceUpdateNavCircuitBreakerReferenceValue(self, flashSwapRouter, ammRouter, dsId);
    }

    function forceUpdateNavCircuitBreakerReferenceValue(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook ammRouter,
        uint256 dsId
    ) internal {
        uint256 nav = _calculateSpotNav(self, flashSwapRouter, ammRouter, dsId);
        self.vault.config.navCircuitBreaker.forceUpdateSnapshot(nav);
    }

    // this will give user their respective balance in mixed form of CT, DS, RA, PA
    function redeemEarly(
        State storage self,
        address owner,
        IVault.RedeemEarlyParams calldata redeemParams,
        IVault.ProtocolContracts memory contracts,
        IVault.PermitParams calldata permitParams
    ) external returns (IVault.RedeemEarlyResult memory result) {
        if (permitParams.deadline != 0) {
            DepegSwapLibrary.permit(
                self.vault.lv._address,
                permitParams.rawLvPermitSig,
                owner,
                address(this),
                redeemParams.amount,
                permitParams.deadline,
                "redeemEarlyLv"
            );
        }

        result.id = redeemParams.id;
        result.receiver = owner;

        uint256 dsId = self.globalAssetIdx;

        Pair storage pair = self.info;
        DepegSwap storage ds = self.ds[dsId];

        MathHelper.RedeemResult memory redeemAmount;

        _updateNavCircuitBreakerOnWithdrawal(self, contracts.flashSwapRouter, contracts.ammRouter, dsId);

        {
            uint256 lpBalance = self.lpBalance();

            MathHelper.RedeemParams memory params = MathHelper.RedeemParams({
                amountLvClaimed: redeemParams.amount,
                totalLvIssued: Asset(self.vault.lv._address).totalSupply(),
                totalVaultLp: lpBalance,
                totalVaultCt: self.vault.balances.ctBalance,
                totalVaultDs: contracts.flashSwapRouter.getLvReserve(redeemParams.id, dsId),
                totalVaultPA: self.vault.pool.withdrawalPool.paBalance,
                totalVaultIdleRa: self.vault.balances.ra.locked
            });

            redeemAmount = MathHelper.calculateRedeemLv(params);
            result.ctReceivedFromVault = redeemAmount.ctReceived;

            result.dsReceived = redeemAmount.dsReceived;
            result.raIdleReceived = redeemAmount.idleRaReceived;
            result.paReceived = redeemAmount.paReceived;
        }

        {
            (uint256 raFromAmm, uint256 ctFromAmm) = __liquidateUnchecked(
                self, pair.ra, ds.ct, contracts.ammRouter, redeemAmount.lpLiquidated, redeemParams.ammDeadline
            );

            result.raReceivedFromAmm = raFromAmm;
            result.ctReceivedFromAmm = ctFromAmm;
        }

        _decreaseInternalBalanceAfterRedeem(self, result);

        if (result.raReceivedFromAmm < redeemParams.amountOutMin) {
            revert IErrors.InsufficientOutputAmount(redeemParams.amountOutMin, result.raReceivedFromAmm);
        }

        if (result.ctReceivedFromAmm + result.ctReceivedFromVault < redeemParams.ctAmountOutMin) {
            revert IErrors.InsufficientOutputAmount(
                redeemParams.ctAmountOutMin, result.ctReceivedFromAmm + result.ctReceivedFromVault
            );
        }

        if (result.dsReceived < redeemParams.dsAmountOutMin) {
            revert IErrors.InsufficientOutputAmount(redeemParams.dsAmountOutMin, result.dsReceived);
        }

        if (result.paReceived < redeemParams.paAmountOutMin) {
            revert IErrors.InsufficientOutputAmount(redeemParams.paAmountOutMin, result.paReceived);
        }

        ERC20Burnable(self.vault.lv._address).burnFrom(owner, redeemParams.amount);

        // fetch ds from flash swap router
        contracts.flashSwapRouter.emptyReservePartialLv(redeemParams.id, dsId, result.dsReceived);

        uint256 raReceived = result.raReceivedFromAmm + result.raIdleReceived;
        {
            IWithdrawalRouter.Tokens[] memory tokens = new IWithdrawalRouter.Tokens[](4);

            tokens[0] = IWithdrawalRouter.Tokens(pair.ra, raReceived);
            tokens[1] = IWithdrawalRouter.Tokens(ds.ct, result.ctReceivedFromVault + result.ctReceivedFromAmm);
            tokens[2] = IWithdrawalRouter.Tokens(ds._address, result.dsReceived);
            tokens[3] = IWithdrawalRouter.Tokens(pair.pa, result.paReceived);

            bytes32 withdrawalId = contracts.withdrawalContract.add(owner, tokens);

            result.withdrawalId = withdrawalId;
        }

        // send RA amm to user
        self.vault.balances.ra.unlockToUnchecked(raReceived, address(contracts.withdrawalContract));

        // send CT received from AMM and held in vault to user
        SafeERC20.safeTransfer(
            IERC20(ds.ct), address(contracts.withdrawalContract), result.ctReceivedFromVault + result.ctReceivedFromAmm
        );

        // send DS to user
        SafeERC20.safeTransfer(IERC20(ds._address), address(contracts.withdrawalContract), result.dsReceived);

        // send PA to user
        SafeERC20.safeTransfer(IERC20(pair.pa), address(contracts.withdrawalContract), result.paReceived);
    }

    function _decreaseInternalBalanceAfterRedeem(State storage self, IVault.RedeemEarlyResult memory result) internal {
        self.vault.balances.ra.decLocked(result.raIdleReceived);
        self.vault.balances.ctBalance -= result.ctReceivedFromVault;
        self.vault.pool.withdrawalPool.paBalance -= result.paReceived;
    }

    function vaultLp(State storage self, ICorkHook ammRotuer) internal view returns (uint256) {
        return self.lpBalance();
    }

    function requestLiquidationFunds(State storage self, uint256 amount, address to) internal {
        if (amount > self.vault.pool.withdrawalPool.paBalance) {
            revert IErrors.InsufficientFunds();
        }

        self.vault.pool.withdrawalPool.paBalance -= amount;
        SafeERC20.safeTransfer(IERC20(self.info.pa), to, amount);
    }

    function receiveTradeExecuctionResultFunds(State storage self, uint256 amount, address from) internal {
        self.vault.balances.ra.lockFrom(amount, from);
    }

    function useTradeExecutionResultFunds(State storage self, IDsFlashSwapCore flashSwapRouter, ICorkHook ammRouter)
        internal
        returns (uint256 raFunds)
    {
        // convert to free and reset ra balance
        raFunds = self.vault.balances.ra.convertAllToFree();
        self.vault.balances.ra.reset();

        __provideLiquidityWithRatio(self, raFunds, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }

    function liquidationFundsAvailable(State storage self) internal view returns (uint256) {
        return self.vault.pool.withdrawalPool.paBalance;
    }

    function tradeExecutionFundsAvailable(State storage self) internal view returns (uint256) {
        return self.vault.balances.ra.locked;
    }

    function receiveLeftoverFunds(State storage self, uint256 amount, address from) internal {
        // transfer PA to the vault
        SafeERC20.safeTransferFrom(IERC20(self.info.pa), from, address(this), amount);
        self.vault.pool.withdrawalPool.paBalance += amount;
    }

    function updateLvDepositsStatus(State storage self, bool isLVDepositPaused) external {
        self.vault.config.isDepositPaused = isLVDepositPaused;
    }

    function updateLvWithdrawalsStatus(State storage self, bool isLVWithdrawalPaused) external {
        self.vault.config.isWithdrawalPaused = isLVWithdrawalPaused;
    }

    function updateNavThreshold(State storage self, uint256 navThreshold) external {
        self.vault.config.navCircuitBreaker.navThreshold = navThreshold;
    }
}
