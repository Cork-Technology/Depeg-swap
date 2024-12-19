// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {State, VaultState, VaultConfig, VaultWithdrawalPool, VaultAmmLiquidityPool} from "./State.sol";
import {VaultConfigLibrary} from "./VaultConfig.sol";
import {Pair, PairLibrary, Id} from "./Pair.sol";
import {LvAsset, LvAssetLibrary} from "./LvAssetLib.sol";
import {PsmLibrary} from "./PsmLib.sol";
import {RedemptionAssetManager, RedemptionAssetManagerLibrary} from "./RedemptionAssetManagerLib.sol";
import {MathHelper} from "./MathHelper.sol";
import {Guard} from "./Guard.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {VaultPool, VaultPoolLibrary} from "./VaultPoolLib.sol";
import {MinimalUniswapV2Library} from "./uni-v2/UniswapV2Library.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {IUniswapV2Pair} from "../interfaces/uniswap-v2/pair.sol";
import {DepegSwap, DepegSwapLibrary} from "./DepegSwapLib.sol";
import {Asset, ERC20, ERC20Burnable} from "../core/assets/Asset.sol";
import {ICommon} from "../interfaces/ICommon.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "../interfaces/IVault.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {LiquidityToken} from "Cork-Hook/LiquidityToken.sol";
import {MarketSnapshot} from "Cork-Hook/lib/MarketSnapshot.sol";
import {Withdrawal} from "./../core/Withdrawal.sol";
import {IWithdrawalRouter} from "./../interfaces/IWithdrawalRouter.sol";
import {TransferHelper} from "./TransferHelper.sol";

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
    using RedemptionAssetManagerLibrary for RedemptionAssetManager;
    using BitMaps for BitMaps.BitMap;
    using DepegSwapLibrary for DepegSwap;
    using VaultPoolLibrary for VaultPool;
    using SafeERC20 for IERC20;

    // for avoiding stack too deep errors
    struct Tolerance {
        uint256 ra;
        uint256 ct;
    }

    function initialize(VaultState storage self, address lv, uint256 fee, address ra, uint256 initialArp) external {
        self.config = VaultConfigLibrary.initialize(fee);

        self.lv = LvAssetLibrary.initialize(lv);
        self.balances.ra = RedemptionAssetManagerLibrary.initialize(ra);
        self.initialArp = initialArp;
    }

    function __addLiquidityToAmmUnchecked(
        State storage self,
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

        _liquidateIfExpired(self, prevDsId, ammRouter, flashSwapRouter, deadline);

        __provideAmmLiquidityFromPool(self, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }

    function _liquidateIfExpired(
        State storage self,
        uint256 dsId,
        ICorkHook ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        uint256 deadline
    ) internal {
        DepegSwap storage ds = self.ds[dsId];

        // we don't want to revert here for easier control flow, expiry check should happen at contract level not library level
        if (!ds.isExpired()) {
            return;
        }

        if (!self.vault.lpLiquidated.get(dsId)) {
            _liquidatedLp(self, dsId, ammRouter, flashSwapRouter, deadline);
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
        bool isRollover = flashSwapRouter.isRolloverSale(id, dsId);

        uint256 marketRatio;

        try flashSwapRouter.getCurrentPriceRatio(id, dsId) returns (uint256, uint256 _marketRatio) {
            marketRatio = _marketRatio;
        } catch {
            marketRatio = 0;
        }

        ratio = _determineRatio(hpa, marketRatio, self.vault.initialArp, isRollover, dsId);
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

        // no need to provide liquidity if the amount is 0
        if (raAmount == 0 || ctAmount == 0) {
            return (0, 0);
        }

        // we use the returned value here since the amount is already normalized
        ctAmount =
            PsmLibrary.unsafeIssueToLv(self, MathHelper.calculateProvideLiquidityAmount(amountRaOriginal, raAmount));

        (lp, dust) = __addLiquidityToAmmUnchecked(
            self, raAmount, ctAmount, self.info.redemptionAsset(), ctAddress, ammRouter, tolerance.ra, tolerance.ct
        );
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[dsId], ctAmount);
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
            revert ICommon.ZeroDeposit();
        }
        safeBeforeExpired(self);

        self.vault.balances.ra.lockUnchecked(amount, from);

        uint256 splitted;
        // split the RA first according to the lv strategy
        (amount, splitted) = _splitCtWithStrategy(self, flashSwapRouter, amount);

        uint256 dsId = self.globalAssetIdx;

        uint256 lp;
        {
            address ct = self.ds[dsId].ct;

            (,, lp) = __provideLiquidityWithRatioGetLP(
                self, amount, flashSwapRouter, ct, ammRouter, Tolerance(raTolerance, ctTolerance)
            );
        }

        // we mint 1:1 if it's the first deposit, else we mint based on current vault NAV
        if (!self.vault.initialized) {
            received = amount;
            self.vault.initialized = true;
        } else {
            received = _calculateReceivedDeposit(self, ammRouter, splitted, lp, dsId, amount, flashSwapRouter);
        }

        self.vault.lv.issue(from, received);
    }

    function _calculateReceivedDeposit(
        State storage self,
        ICorkHook ammRouter,
        uint256 ctSplitted,
        uint256 lpGenerated,
        uint256 dsId,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter
    ) internal returns (uint256 received) {
        Id id = self.info.toId();
        address ct = self.ds[dsId].ct;
        MarketSnapshot memory snapshot = ammRouter.getMarketSnapshot(self.info.ra, ct);
        uint256 lpSupply = IERC20(snapshot.liquidityToken).totalSupply() - lpGenerated;

        // we convert ra reserve to 18 decimals to get accurate results
        snapshot.reserveRa = TransferHelper.tokenNativeDecimalsToFixed(snapshot.reserveRa, self.info.ra);

        MathHelper.DepositParams memory params = MathHelper.DepositParams({
            depositAmount: amount,
            reserveRa: snapshot.reserveRa,
            reserveCt: snapshot.reserveCt,
            oneMinusT: snapshot.oneMinusT,
            lpSupply: lpSupply,
            lvSupply: Asset(self.vault.lv._address).totalSupply(),
            // the provide liquidity automatically adds the lp, so we need to subtract it first here
            vaultCt: self.vault.balances.ctBalance - ctSplitted,
            vaultDs: flashSwapRouter.getLvReserve(id, dsId) - ctSplitted,
            vaultLp: IERC20(snapshot.liquidityToken).balanceOf(address(this)),
            vaultIdleRa: self.vault.pool.ammLiquidityPool.balance
        });

        received = MathHelper.calculateDepositLv(params);
    }

    function updateCtHeldPercentage(State storage self, uint256 ctHeldPercentage) external {
        // must be between 0% and 100%
        if (ctHeldPercentage >= 100 ether) {
            revert IVault.InvalidParams();
        }

        self.vault.ctHeldPercetage = ctHeldPercentage;
    }

    function _splitCt(State storage self, uint256 amount) internal view returns (uint256 splitted) {
        uint256 ctHeldPercentage = self.vault.ctHeldPercetage;
        splitted = MathHelper.calculatePercentageFee(ctHeldPercentage, amount);
    }

    function _splitCtWithStrategy(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 amount)
        internal
        returns (uint256 amountLeft, uint256 splitted)
    {
        splitted = _splitCt(self, amount);

        amountLeft = amount - splitted;

        // actually mint ct & ds to vault and used the normalized value
        uint256 ctDsReceivedNormalized = PsmLibrary.unsafeIssueToLv(self, splitted);

        // increase the ct balance in the vault
        self.vault.balances.ctBalance += ctDsReceivedNormalized;

        // add ds to flash swap reserve
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[self.globalAssetIdx], ctDsReceivedNormalized);
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
    }

    function _liquidatedLp(
        State storage self,
        uint256 dsId,
        ICorkHook ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        uint256 deadline
    ) internal {
        DepegSwap storage ds = self.ds[dsId];
        uint256 lpBalance;
        {
            IERC20 lpToken = IERC20(ammRouter.getLiquidityToken(self.info.ra, ds.ct));
            lpBalance = lpToken.balanceOf(address(this));
        }

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
        _redeemCtVault(self, flashSwapRouter, dsId, ctAmm, raAmm);
    }

    function _redeemCtVault(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        uint256 dsId,
        uint256 ctAmm,
        uint256 raAmm
    ) internal {
        uint256 psmPa;
        uint256 psmRa;

        (psmPa, psmRa) = PsmLibrary.lvRedeemRaPaWithCt(self, ctAmm, dsId);

        psmRa += raAmm;

        self.vault.pool.reserve(self.vault.lv.totalIssued(), psmRa, psmPa);
    }

    // duplicate function to avoid stack too deep error
    function __calculateTotalRaAndCtBalance(State storage self, ICorkHook ammRouter, uint256 dsId)
        internal
        view
        returns (uint256 totalRa, uint256 ammCtBalance)
    {
        address ra = self.info.ra;
        address ct = self.ds[dsId].ct;

        (uint256 raReserve, uint256 ctReserve) = ammRouter.getReserves(ra, ct);

        uint256 lpTotal;
        uint256 lpBalance;
        {
            LiquidityToken lp = LiquidityToken(ammRouter.getLiquidityToken(ra, ct));
            lpBalance = lp.balanceOf(address(this));
            lpTotal = lp.totalSupply();
        }

        (,,,, totalRa, ammCtBalance) =
            __calculateTotalRaAndCtBalanceWithReserve(self, raReserve, ctReserve, lpTotal, lpBalance);
    }

    // duplicate function to avoid stack too deep error
    function __calculateCtBalanceWithRate(State storage self, ICorkHook ammRouter, uint256 dsId)
        internal
        view
        returns (uint256 raPerLv, uint256 ctPerLv, uint256 raPerLp, uint256 ctPerLp)
    {
        address ra = self.info.ra;
        address ct = self.ds[dsId].ct;

        (uint256 raReserve, uint256 ctReserve) = ammRouter.getReserves(ra, ct);

        uint256 lpTotal;
        uint256 lpBalance;
        {
            LiquidityToken lp = LiquidityToken(ammRouter.getLiquidityToken(ra, ct));
            lpBalance = lp.balanceOf(address(this));
            lpTotal = lp.totalSupply();
        }

        (,, raPerLv, ctPerLv, raPerLp, ctPerLp) =
            __calculateTotalRaAndCtBalanceWithReserve(self, raReserve, ctReserve, lpTotal, lpBalance);
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

    function _getRaCtReserveSorted(State storage self, ICorkHook ammRouter, uint256 dsId)
        internal
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        address ra = self.info.ra;
        address ct = self.ds[dsId].ct;

        (raReserve, ctReserve) = ammRouter.getReserves(ra, ct);
    }

    // IMPORTANT : only psm, flash swap router and early redeem LV can call this function
    function provideLiquidityWithFee(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook ammRouter
    ) public {
        __provideLiquidityWithRatio(self, amount, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }

    // this will give user their respective balance in mixed form of CT, DS, RA, PA
    function redeemEarly(
        State storage self,
        address owner,
        IVault.RedeemEarlyParams memory redeemParams,
        IVault.ProtocolContracts memory contracts,
        IVault.PermitParams memory permitParams
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
        result.feePercentage = self.vault.config.fee;
        result.fee = MathHelper.calculatePercentageFee(result.feePercentage, redeemParams.amount);

        redeemParams.amount -= result.fee;

        result.id = redeemParams.id;
        result.receiver = owner;

        uint256 dsId = self.globalAssetIdx;

        Pair storage pair = self.info;
        DepegSwap storage ds = self.ds[dsId];

        MathHelper.RedeemResult memory redeemAmount;
        {
            uint256 lpBalance;
            {
                IERC20 lpToken = IERC20(contracts.ammRouter.getLiquidityToken(pair.ra, ds.ct));
                lpBalance = lpToken.balanceOf(address(this));
            }

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
            // decrease the ct balance in the vault
            self.vault.balances.ctBalance -= result.ctReceivedFromVault;

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

        if (result.raReceivedFromAmm < redeemParams.amountOutMin) {
            revert IVault.InsufficientOutputAmount(redeemParams.amountOutMin, result.raReceivedFromAmm);
        }

        // burn lv amount + fee
        ERC20Burnable(self.vault.lv._address).burnFrom(owner, redeemParams.amount + result.fee);

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

    function vaultLp(State storage self, ICorkHook ammRotuer) internal view returns (uint256) {
        uint256 lpBalance;

        IERC20 lpToken = IERC20(ammRotuer.getLiquidityToken(self.info.ra, self.ds[self.globalAssetIdx].ct));
        lpBalance = lpToken.balanceOf(address(this));

        return lpBalance;
    }

    function requestLiquidationFunds(State storage self, uint256 amount, address to) internal {
        if (amount > self.vault.pool.withdrawalPool.paBalance) {
            revert IVault.InsufficientFunds();
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
}
