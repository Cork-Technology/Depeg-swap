// SPDX-License-Identifier: BUSL-1.1
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
import {IUniswapV2Pair} from "../interfaces/uniswap-v2/pair.sol";
import {DepegSwap, DepegSwapLibrary} from "./DepegSwapLib.sol";
import {Asset, ERC20, ERC20Burnable} from "../core/assets/Asset.sol";
import {ICommon} from "../interfaces/ICommon.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "../interfaces/IVault.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {LiquidityToken} from "Cork-Hook/LiquidityToken.sol";

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
        ICorkHook ammRouter,
        uint256 raTolerance,
        uint256 ctTolerance
    ) internal returns (uint256 lp) {
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
        ICorkHook ammRouter,
        uint256 deadline
    ) external {
        // do nothing at first issuance
        if (prevDsId == 0) {
            return;
        }

        if (!self.vault.lpLiquidated.get(prevDsId)) {
            _liquidatedLp(self, prevDsId, ammRouter, flashSwapRouter, deadline);
            _redeemCtStrategy(self, prevDsId);
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
        ICorkHook ammRouter,
        Tolerance memory tolerance
    ) internal returns (uint256 ra, uint256 ct, uint256 lp) {
        (ra, ct) = __calculateProvideLiquidityAmount(self, amount, flashSwapRouter);

        lp = __provideLiquidity(self, ra, ct, flashSwapRouter, ctAddress, ammRouter, tolerance, amount);
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
        uint256 hpa = flashSwapRouter.getCurrentEffectiveHPA(id);
        bool isRollover = flashSwapRouter.isRolloverSale(id, dsId);

        uint256 marketRatio;

        try flashSwapRouter.getCurrentPriceRatio(id, dsId) returns (uint256, uint256 _marketRatio) {
            marketRatio = _marketRatio;
        } catch {
            marketRatio = 0;
        }

        ratio = _determineRatio(hpa, marketRatio, self.vault.initialDsPrice, isRollover, dsId);
    }

    function _determineRatio(uint256 hpa, uint256 marketRatio, uint256 initialDsPrice, bool isRollover, uint256 dsId)
        internal
        pure
        returns (uint256 ratio)
    {
        // fallback to initial ds price ratio if hpa is 0, and market ratio is 0
        // usually happens when there's no trade on the router AND is not the first issuance
        // OR it's the first issuance
        if (hpa == 0 && marketRatio == 0) {
            ratio = 1e18 - initialDsPrice;
            return ratio;
        }

        // this will return the hpa as ratio when it's basically not the first issuance, and there's actually an hpa to rely on
        // we must specifically check for market ratio since, we want to trigger this only when there's no market ratio(i.e freshly after a rollover)
        if (dsId != 1 && isRollover && hpa != 0 && marketRatio == 0) {
            ratio = hpa;
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
    ) internal returns (uint256 lp) {
        uint256 dsId = self.globalAssetIdx;

        // no need to provide liquidity if the amount is 0
        if (raAmount == 0 || ctAmount == 0) {
            return 0;
        }

        PsmLibrary.unsafeIssueToLv(self, MathHelper.calculateProvideLiquidityAmount(amountRaOriginal, raAmount));

        lp = __addLiquidityToAmmUnchecked(
            self, raAmount, ctAmount, self.info.redemptionAsset(), ctAddress, ammRouter, tolerance.ra, tolerance.ct
        );
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[dsId], ctAmount);
    }

    function __provideAmmLiquidityFromPool(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook ammRouter
    ) internal {
        uint256 dsId = self.globalAssetIdx;

        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (uint256 ra, uint256 ct, uint256 originalBalance) = self.vault.pool.rationedToAmm(ctRatio);

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

        uint256 exchangeRate;

        (,, uint256 lp) = __provideLiquidityWithRatio(
            self,
            amount,
            flashSwapRouter,
            self.ds[self.globalAssetIdx].ct,
            ammRouter,
            Tolerance(raTolerance, ctTolerance)
        );

        {
            MathHelper.DepositParams memory params = MathHelper.DepositParams({
                totalLvIssued: Asset(self.vault.lv._address).totalSupply(),
                // the provide liquidity automatically adds the lp, so we need to subtract it first here
                totalVaultLp: self.vault.config.lpBalance - lp,
                totalLpMinted: lp,
                totalVaultCt: self.vault.balances.ctBalance - splitted,
                totalCtMinted: splitted,
                totalVaultDs: flashSwapRouter.getLvReserve(self.info.toId(), self.globalAssetIdx) - splitted,
                totalDsMinted: splitted
            });

            received = MathHelper.calculateDepositLv(params);
        }

        self.vault.lv.issue(from, received);

        self.vault.userLvBalance[from].balance += received;
    }

    function updateCtHeldPercentage(State storage self, uint256 ctHeldPercentage) external {
        // must be between 0.001% and 100%
        if (ctHeldPercentage > 100 ether || ctHeldPercentage < 0.001 ether) {
            revert IVault.InvalidParams();
        }

        self.vault.ctHeldPercetage = ctHeldPercentage;
    }

    function _splitCt(State storage self, uint256 amount) internal view returns (uint256 splitted) {
        uint256 ctHeldPercentage = self.vault.ctHeldPercetage;
        splitted = MathHelper.calculatePercentageFee(ctHeldPercentage, amount);
    }
    // TODO : test

    function _splitCtWithStrategy(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 amount)
        internal
        returns (uint256 amountLeft, uint256 splitted)
    {
        splitted = _splitCt(self, amount);

        // increase the ct balance in the vault
        self.vault.balances.ctBalance += splitted;

        amountLeft = amount - splitted;

        // actually mint ct & ds to vault
        PsmLibrary.unsafeIssueToLv(self, splitted);

        // add ds to flash swap reserve
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[self.globalAssetIdx], splitted);
    }

    // TODO : test
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

    // Calculates PA amount as per price of PA with LV total supply, PA balance and given LV amount
    // lv price = paReserve / lvTotalSupply
    // PA amount = lvAmount * (PA reserve in contract / total supply of LV)
    function _calculatePaPriceForLv(State storage self, uint256 lvAmt) internal view returns (uint256 paAmount) {
        return lvAmt * self.vault.pool.withdrawalPool.paBalance / ERC20(self.vault.lv._address).totalSupply();
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

        self.vault.config.lpBalance -= lp;
    }

    function _liquidatedLp(
        State storage self,
        uint256 dsId,
        ICorkHook ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        uint256 deadline
    ) internal {
        DepegSwap storage ds = self.ds[dsId];
        uint256 lpBalance = self.vault.config.lpBalance;

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

        (uint256 raAmm, uint256 ctAmm) =
            __liquidateUnchecked(self, self.info.pair1, ds.ct, ammRouter, lpBalance, deadline);

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

    // duplicate function to avoid stack too deep error
    function __calculateTotalRaAndCtBalance(State storage self, ICorkHook ammRouter, uint256 dsId)
        internal
        view
        returns (uint256 totalRa, uint256 ammCtBalance)
    {
        address ra = self.info.pair1;
        address ct = self.ds[dsId].ct;

        (uint256 raReserve, uint256 ctReserve) = ammRouter.getReserves(ra, ct);

        uint256 lpTotal = LiquidityToken(ammRouter.getLiquidityToken(ra, ct)).totalSupply();

        (,,,, totalRa, ammCtBalance) = __calculateTotalRaAndCtBalanceWithReserve(self, raReserve, ctReserve, lpTotal);
    }

    // duplicate function to avoid stack too deep error
    function __calculateCtBalanceWithRate(State storage self, ICorkHook ammRouter, uint256 dsId)
        internal
        view
        returns (uint256 raPerLv, uint256 ctPerLv, uint256 raPerLp, uint256 ctPerLp)
    {
        address ra = self.info.pair1;
        address ct = self.ds[dsId].ct;

        (uint256 raReserve, uint256 ctReserve) = ammRouter.getReserves(ra, ct);

        uint256 lpTotal = LiquidityToken(ammRouter.getLiquidityToken(ra, ct)).totalSupply();

        (,, raPerLv, ctPerLv, raPerLp, ctPerLp) =
            __calculateTotalRaAndCtBalanceWithReserve(self, raReserve, ctReserve, lpTotal);
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
        (raPerLv, ctPerLv, raPerLp, ctPerLp, totalRa, ammCtBalance) = MathHelper.calculateLvValueFromUniLp(
            lpSupply, self.vault.config.lpBalance, raReserve, ctReserve, Asset(self.vault.lv._address).totalSupply()
        );
    }

    function _getRaCtReserveSorted(State storage self, ICorkHook ammRouter, uint256 dsId)
        internal
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        address ra = self.info.pair1;
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
    // TODO : test
    function redeemEarly(
        State storage self,
        address owner,
        IVault.RedeemEarlyParams memory redeemParams,
        IVault.Routers memory routers,
        IVault.PermitParams memory permitParams
    ) external returns (IVault.RedeemEarlyResult memory result) {
        safeBeforeExpired(self);
        if (permitParams.deadline != 0) {
            DepegSwapLibrary.permit(
                self.vault.lv._address,
                permitParams.rawLvPermitSig,
                owner,
                address(this),
                redeemParams.amount,
                permitParams.deadline
            );
        }

        result.receiver = owner;

        result.feePercentage = self.vault.config.fee;

        result.paReceived = _redeemPa(self, redeemParams, owner);

        {
            MathHelper.RedeemParams memory params = MathHelper.RedeemParams({
                amountLvBurned: redeemParams.amount,
                totalLvIssued: Asset(self.vault.lv._address).totalSupply(),
                totalVaultLp: self.vault.config.lpBalance,
                totalVaultCt: self.vault.balances.ctBalance,
                totalVaultDs: routers.flashSwapRouter.getLvReserve(self.info.toId(), self.globalAssetIdx)
            });

            (uint256 ctReceived, uint256 dsReceived, uint256 lpLiquidated) = MathHelper.calculateRedeemLv(params);

            result.ctReceivedFromVault = ctReceived;
            result.dsReceived = dsReceived;

            (uint256 raFromAmm, uint256 ctFromAmm) = __liquidateUnchecked(
                self,
                self.info.pair1,
                self.ds[self.globalAssetIdx].ct,
                routers.ammRouter,
                lpLiquidated,
                redeemParams.ammDeadline
            );

            result.raReceivedFromAmm = raFromAmm;
            result.ctReceivedFromAmm = ctFromAmm;
        }

        result.raFee = MathHelper.calculatePercentageFee(result.raReceivedFromAmm, result.feePercentage);

        if (result.raFee != 0) {
            provideLiquidityWithFee(self, result.raFee, routers.flashSwapRouter, routers.ammRouter);
            result.raReceivedFromAmm = result.raReceivedFromAmm - result.raFee;
        }

        if (result.raReceivedFromAmm < redeemParams.amountOutMin) {
            revert IVault.InsufficientOutputAmount(redeemParams.amountOutMin, result.raReceivedFromAmm);
        }

        ERC20Burnable(self.vault.lv._address).burnFrom(owner, redeemParams.amount);
        self.vault.balances.ra.unlockToUnchecked(result.raReceivedFromAmm, redeemParams.receiver);
    }

    function _redeemPa(State storage self, IVault.RedeemEarlyParams memory redeemParams, address owner)
        internal
        returns (uint256 paAmount)
    {
        uint256 paRedeemAmount = redeemParams.amount;

        if (redeemParams.amount > self.vault.userLvBalance[owner].balance) {
            paRedeemAmount = self.vault.userLvBalance[owner].balance;
        }

        self.vault.userLvBalance[owner].balance -= paRedeemAmount;

        paAmount = _calculatePaPriceForLv(self, redeemParams.amount);
        self.vault.pool.withdrawalPool.paBalance -= paAmount;
        ERC20(self.info.pair0).transfer(owner, paAmount);
    }
}
