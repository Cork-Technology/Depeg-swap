// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Asset, ERC20Burnable} from "../core/assets/Asset.sol";
import {Pair, PairLibrary, Id} from "./Pair.sol";
import {DepegSwap, DepegSwapLibrary} from "./DepegSwapLib.sol";
import {RedemptionAssetManager, RedemptionAssetManagerLibrary} from "./RedemptionAssetManagerLib.sol";
import {Signature, MinimalSignatureHelper} from "./SignatureHelperLib.sol";
import {PeggedAsset, PeggedAssetLibrary} from "./PeggedAssetLib.sol";
import {State, BitMaps, Balances, PsmPoolArchive} from "./State.sol";
import {Guard} from "./Guard.sol";
import {MathHelper} from "./MathHelper.sol";
import {IRepurchase} from "../interfaces/IRepurchase.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {IPSMcore} from "../interfaces/IPSMcore.sol";
import {VaultLibrary} from "./VaultLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransferHelper} from "./TransferHelper.sol";
import {IExchangeRateProvider} from "./../interfaces/IExchangeRateProvider.sol";

/**
 * @title Psm Library Contract
 * @author Cork Team
 * @notice Psm Library implements functions for PSM Core contract
 */
library PsmLibrary {
    using MinimalSignatureHelper for Signature;
    using PairLibrary for Pair;
    using DepegSwapLibrary for DepegSwap;
    using RedemptionAssetManagerLibrary for RedemptionAssetManager;
    using PeggedAssetLibrary for PeggedAsset;
    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;

    /**
     *   This denotes maximum fee allowed in contract
     *   Here 1 ether = 1e18 so maximum 5% fee allowed
     */
    uint256 internal constant MAX_ALLOWED_FEES = 5 ether;

    /// @notice inssuficient balance to perform rollover redeem(e.g having 5 CT worth of rollover to redeem but trying to redeem 10)
    error InsufficientRolloverBalance(address caller, uint256 requested, uint256 balance);

    /// @notice thrown when trying to rollover while no active issuance
    error NoActiveIssuance();

    function isInitialized(State storage self) external view returns (bool status) {
        status = self.info.isInitialized();
    }

    function _getLatestRate(State storage self) internal view returns (uint256 rate) {
        Id id = self.info.toId();

        uint256 exchangeRates = IExchangeRateProvider(self.info.exchangeRateProvider).rate();

        if (exchangeRates == 0) {
            exchangeRates = IExchangeRateProvider(self.info.exchangeRateProvider).rate(id);
        }

        return exchangeRates;
    }

    function _getLatestApplicableRate(State storage self) internal view returns (uint256 rate) {
        uint256 externalExchangeRates = _getLatestRate(self);
        uint256 currentExchangeRates = Asset(self.ds[self.globalAssetIdx]._address).exchangeRate();

        // return the lower of the two
        return externalExchangeRates < currentExchangeRates ? externalExchangeRates : currentExchangeRates;
    }

    // fetch and update the exchange rate. will return the lowest rate
    function _getLatestApplicableRateAndUpdate(State storage self) internal returns (uint256 rate) {
        rate = _getLatestApplicableRate(self);
        self.ds[self.globalAssetIdx].updateExchangeRate(rate);
    }

    function initialize(State storage self, Pair calldata key) external {
        self.info = key;
        self.psm.balances.ra = RedemptionAssetManagerLibrary.initialize(key.redemptionAsset());
    }

    function updateAutoSell(State storage self, address user, bool status) external {
        self.psm.autoSell[user] = status;
    }

    function autoSellStatus(State storage self, address user) external view returns (bool status) {
        return self.psm.autoSell[user];
    }

    function acceptRolloverProfit(State storage self, uint256 amount) external {
        self.psm.poolArchive[self.globalAssetIdx].rolloverProfit += amount;
    }

    function rolloverExpiredCt(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived) {
        if (rawCtPermitSig.length > 0 && ctDeadline != 0) {
            DepegSwapLibrary.permit(
                self.ds[dsId].ct, rawCtPermitSig, owner, address(this), amount, ctDeadline, "rolloverExpiredCt"
            );
        }

        (ctReceived, dsReceived, paReceived) = _rolloverExpiredCt(self, owner, amount, dsId, flashSwapRouter);
    }

    function claimAutoSellProfit(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        address owner,
        uint256 dsId,
        uint256 amount
    ) external returns (uint256 profit, uint256 remainingDsReceived) {
        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }

        (profit, remainingDsReceived) =
            _claimAutoSellProfit(self, self.psm.poolArchive[dsId], flashSwapRouter, owner, amount, dsId);
    }
    // 1. check how much expirec CT does use have
    // 2. calculate how much backed RA and PA the user can redeem
    // 3. mint new CT and DS equal to backed RA user has
    // 4. send DS to flashswap router if user opt-in for auto sell or send to user if not
    // 5. send CT to user
    // 6. send RA to user if they don't opt-in for auto sell
    // 7. send PA to user
    // regardless of amount, it will always send user all the profit from rollover

    function _rolloverExpiredCt(
        State storage self,
        address owner,
        uint256 amount,
        uint256 prevDsId,
        IDsFlashSwapCore flashSwapRouter
    ) internal returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived) {
        if (prevDsId == self.globalAssetIdx) {
            revert NoActiveIssuance();
        }

        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }

        // claim logic
        PsmPoolArchive storage prevArchive;

        uint256 accruedRa;
        // avoid stack too deep error
        (prevArchive, accruedRa, paReceived) = _claimCtForRollover(self, prevDsId, amount, owner);

        // deposit logic
        DepegSwap storage currentDs = self.ds[self.globalAssetIdx];
        Guard.safeBeforeExpired(currentDs);

        // by default the amount of CT received is the same as the amount of RA deposited
        // we convert it to 18 fixed decimals, since that's what the DS uses
        ctReceived = TransferHelper.tokenNativeDecimalsToFixed(accruedRa, self.info.ra);

        // by default the amount of DS received is the same as CT
        dsReceived = ctReceived;

        // increase current ds active RA balance locked
        self.psm.balances.ra.incLocked(accruedRa);

        // increase rollover claims if user opt-in for auto sell, avoid stack too deep error
        dsReceived = _incRolloverClaims(self, ctReceived, owner, dsReceived);
        // end deposit logic

        // send, burn tokens and mint new ones
        _afterRollover(self, currentDs, owner, ctReceived, paReceived, flashSwapRouter);
    }

    function _incRolloverClaims(State storage self, uint256 ctDsReceived, address owner, uint256 dsReceived)
        internal
        returns (uint256)
    {
        if (self.psm.autoSell[owner]) {
            PsmPoolArchive storage currentArchive = self.psm.poolArchive[self.globalAssetIdx];
            currentArchive.attributedToRolloverProfit += ctDsReceived;
            currentArchive.rolloverClaims[owner] += ctDsReceived;
            // we return 0 since the user opt-in for auto sell
            return 0;
        } else {
            return dsReceived;
        }
    }

    function _claimCtForRollover(State storage self, uint256 prevDsId, uint256 amount, address owner)
        private
        returns (PsmPoolArchive storage prevArchive, uint256 accruedRa, uint256 accruedPa)
    {
        DepegSwap storage prevDs = self.ds[prevDsId];
        Guard.safeAfterExpired(prevDs);

        if (Asset(prevDs.ct).balanceOf(owner) < amount) {
            revert InsufficientRolloverBalance(owner, amount, Asset(prevDs.ct).balanceOf(owner));
        }

        // separate liquidity first so that we can properly calculate the attributed amount
        _separateLiquidity(self, prevDsId);
        uint256 totalCtIssued = self.psm.poolArchive[prevDsId].ctAttributed;
        prevArchive = self.psm.poolArchive[prevDsId];

        // caclulate accrued RA and PA proportional to CT amount
        (accruedPa, accruedRa) =
            _calcRedeemAmount(self, amount, totalCtIssued, prevArchive.raAccrued, prevArchive.paAccrued);
        // accounting stuff(decrementing reserve etc)
        _beforeCtRedeem(self, prevDs, prevDsId, amount, accruedPa, accruedRa);

        // burn previous CT
        // this would normally go on the end of the the overall logic but needed here to avoid stack to deep error
        ERC20Burnable(prevDs.ct).burnFrom(owner, amount);
    }

    function _claimAutoSellProfit(
        State storage self,
        PsmPoolArchive storage prevArchive,
        IDsFlashSwapCore flashswapRouter,
        address owner,
        uint256 amount,
        uint256 prevDsId
    ) private returns (uint256 rolloverProfit, uint256 remainingRolloverDs) {
        if (prevArchive.rolloverClaims[owner] < amount) {
            revert InsufficientRolloverBalance(owner, amount, prevArchive.rolloverClaims[owner]);
        }

        remainingRolloverDs = MathHelper.calculateAccrued(
            amount, flashswapRouter.getPsmReserve(self.info.toId(), prevDsId), prevArchive.attributedToRolloverProfit
        );

        if (remainingRolloverDs != 0) {
            flashswapRouter.emptyReservePartialPsm(self.info.toId(), prevDsId, remainingRolloverDs);
        }

        // calculate their share of profit
        rolloverProfit = MathHelper.calculateAccrued(
            amount,
            TransferHelper.tokenNativeDecimalsToFixed(prevArchive.rolloverProfit, self.info.ra),
            prevArchive.attributedToRolloverProfit
        );
        rolloverProfit = TransferHelper.fixedToTokenNativeDecimals(rolloverProfit, self.info.ra);

        // reset their claim
        prevArchive.rolloverClaims[owner] -= amount;
        // decrement total profit
        prevArchive.rolloverProfit -= rolloverProfit;
        // decrement total ct attributed to rollover
        prevArchive.attributedToRolloverProfit -= amount;

        IERC20(self.info.redemptionAsset()).safeTransfer(owner, rolloverProfit);

        if (remainingRolloverDs != 0) {
            // mint DS to user
            IERC20(self.ds[prevDsId]._address).safeTransfer(owner, remainingRolloverDs);
        }
    }

    function _afterRollover(
        State storage self,
        DepegSwap storage currentDs,
        address owner,
        uint256 ctDsReceived,
        uint256 accruedPa,
        IDsFlashSwapCore flashSwapRouter
    ) private {
        if (self.psm.autoSell[owner]) {
            // send DS to flashswap router if auto sellf
            Asset(currentDs._address).mint(address(this), ctDsReceived);
            IERC20(currentDs._address).safeIncreaseAllowance(address(flashSwapRouter), ctDsReceived);

            flashSwapRouter.addReservePsm(self.info.toId(), self.globalAssetIdx, ctDsReceived);
        } else {
            // mint DS to user
            Asset(currentDs._address).mint(owner, ctDsReceived);
        }

        // mint new CT to user
        Asset(currentDs.ct).mint(owner, ctDsReceived);
        // transfer accrued PA to user
        self.info.peggedAsset().asErc20().safeTransfer(owner, accruedPa);
    }

    /// @notice issue a new pair of DS, will fail if the previous DS isn't yet expired
    function onNewIssuance(State storage self, address ct, address ds, uint256 idx, uint256 prevIdx) internal {
        if (prevIdx != 0) {
            DepegSwap storage _prevDs = self.ds[prevIdx];
            Guard.safeAfterExpired(_prevDs);
            _separateLiquidity(self, prevIdx);
        }

        // essentially burn unpurchased ds as we're going in with a new issuance
        self.psm.balances.dsBalance = 0;

        self.ds[idx] = DepegSwapLibrary.initialize(ds, ct);
    }

    function _separateLiquidity(State storage self, uint256 prevIdx) internal {
        if (self.psm.liquiditySeparated.get(prevIdx)) {
            return;
        }

        DepegSwap storage ds = self.ds[prevIdx];
        Guard.safeAfterExpired(ds);

        PsmPoolArchive storage archive = self.psm.poolArchive[prevIdx];

        uint256 availableRa = self.psm.balances.ra.convertAllToFree();
        uint256 availablePa = self.psm.balances.paBalance;

        archive.paAccrued = availablePa;
        archive.raAccrued = availableRa;
        archive.ctAttributed = IERC20(ds.ct).totalSupply();

        // reset current balances
        self.psm.balances.ra.reset();
        self.psm.balances.paBalance = 0;

        self.psm.liquiditySeparated.set(prevIdx);
    }

    /// @notice deposit RA to the PSM
    /// @dev the user must approve the PSM to spend their RA
    function deposit(State storage self, address depositor, uint256 amount)
        external
        returns (uint256 dsId, uint256 received, uint256 _exchangeRate)
    {
        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }

        dsId = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
        _exchangeRate = _getLatestApplicableRateAndUpdate(self);

        // we convert it 18 fixed decimals, since that's what the DS uses
        received = TransferHelper.tokenNativeDecimalsToFixed(amount, self.info.ra);

        self.psm.balances.ra.lockFrom(amount, depositor);

        ds.issue(depositor, received);
    }

    // This is here just for semantics, since in the whitepaper, all the CT DS issuance
    // happens in the PSM, although they essentially lives in the same contract, we leave it here just for consistency sake
    //
    // IMPORTANT: this is unsafe because by issuing CT, we also lock an equal amount of RA into the PSM.
    // it is a must, that the LV won't count the amount being locked in the PSM as it's balances.
    // doing so would create a mismatch between the accounting balance and the actual token balance.
    function unsafeIssueToLv(State storage self, uint256 amount) internal returns (uint256 received) {
        uint256 dsId = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[dsId];

        self.psm.balances.ra.incLocked(amount);

        // we convert it 18 fixed decimals, since that's what the DS uses
        received = TransferHelper.tokenNativeDecimalsToFixed(amount, self.info.ra);

        uint256 exchangeRate = _getLatestApplicableRateAndUpdate(self);

        ds.issue(address(this), received);

        emit IPSMcore.PsmDeposited(self.info.toId(), self.globalAssetIdx, msg.sender, amount, received, exchangeRate);
    }

    function lvRedeemRaPaWithCt(State storage self, uint256 amount, uint256 dsId)
        internal
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        // we separate the liquidity here, that means, LP liquidation on the LV also triggers
        _separateLiquidity(self, dsId);

        // noop if amount is 0
        if (amount == 0) {
            return (0, 0);
        }

        uint256 totalCtIssued = self.psm.poolArchive[dsId].ctAttributed;
        PsmPoolArchive storage archive = self.psm.poolArchive[dsId];

        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount, totalCtIssued, archive.raAccrued, archive.paAccrued);

        _beforeCtRedeem(self, self.ds[dsId], dsId, amount, accruedPa, accruedRa);

        self.ds[dsId].burnCtSelf(amount);
    }

    function _returnRaWithCtDs(State storage self, DepegSwap storage ds, address owner, uint256 amount)
        internal
        returns (uint256 ra)
    {
        ra = TransferHelper.fixedToTokenNativeDecimals(amount, self.info.ra);

        self.psm.balances.ra.unlockTo(owner, ra);

        ERC20Burnable(ds.ct).burnFrom(owner, amount);
        ERC20Burnable(ds._address).burnFrom(owner, amount);
    }

    function returnRaWithCtDs(
        State storage self,
        address owner,
        uint256 amount,
        bytes calldata rawDsPermitSig,
        uint256 dsDeadline,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ra) {
        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }

        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        if (dsDeadline != 0 && ctDeadline != 0) {
            DepegSwapLibrary.permit(
                ds._address, rawDsPermitSig, owner, address(this), amount, dsDeadline, "returnRaWithCtDs"
            );
            DepegSwapLibrary.permit(ds.ct, rawCtPermitSig, owner, address(this), amount, ctDeadline, "returnRaWithCtDs");
        }

        ra = _returnRaWithCtDs(self, ds, owner, amount);
    }

    function availableForRepurchase(State storage self) external view returns (uint256 pa, uint256 ds, uint256 dsId) {
        dsId = self.globalAssetIdx;
        DepegSwap storage _ds = self.ds[dsId];
        Guard.safeBeforeExpired(_ds);

        pa = self.psm.balances.paBalance;
        ds = self.psm.balances.dsBalance;
    }

    function repurchaseRates(State storage self) external view returns (uint256 rates) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        rates = _getLatestApplicableRate(self);
    }

    function repurchaseFeePercentage(State storage self) external view returns (uint256 rates) {
        rates = self.psm.repurchaseFeePercentage;
    }

    function updateRepurchaseFeePercentage(State storage self, uint256 newFees) external {
        if (newFees > MAX_ALLOWED_FEES) {
            revert IErrors.InvalidFees();
        }
        self.psm.repurchaseFeePercentage = newFees;
    }

    function updatePsmDepositsStatus(State storage self, bool isPSMDepositPaused) external {
        self.psm.isDepositPaused = isPSMDepositPaused;
    }

    function updatePsmWithdrawalsStatus(State storage self, bool isPSMWithdrawalPaused) external {
        self.psm.isWithdrawalPaused = isPSMWithdrawalPaused;
    }

    function updatePsmRepurchasesStatus(State storage self, bool isPSMRepurchasePaused) external {
        self.psm.isRepurchasePaused = isPSMRepurchasePaused;
    }

    function previewRepurchase(State storage self, uint256 amount)
        internal
        view
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates,
            DepegSwap storage ds
        )
    {
        dsId = self.globalAssetIdx;

        ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        exchangeRates = _getLatestApplicableRate(self);

        // the fee is taken directly from RA before it's even converted to DS
        {
            Asset dsToken = Asset(ds._address);
            (fee, feePercentage) = MathHelper.calculateRepurchaseFee(
                dsToken.issuedAt(), dsToken.expiry(), block.timestamp, amount, self.psm.repurchaseFeePercentage
            );
        }

        amount = amount - fee;
        amount = TransferHelper.tokenNativeDecimalsToFixed(amount, self.info.ra);

        // we use deposit here because technically the user deposit RA to the PSM when repurchasing
        receivedPa = MathHelper.calculateDepositAmountWithExchangeRate(amount, exchangeRates);
        receivedPa = TransferHelper.fixedToTokenNativeDecimals(receivedPa, self.info.pa);
        receivedDs = amount;

        if (receivedPa > self.psm.balances.paBalance) {
            revert IErrors.InsufficientLiquidity(self.psm.balances.paBalance, receivedPa);
        }

        if (receivedDs > self.psm.balances.dsBalance) {
            revert IErrors.InsufficientLiquidity(amount, self.psm.balances.dsBalance);
        }
    }

    function repurchase(State storage self, address buyer, uint256 amount, address treasury)
        external
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        )
    {
        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }

        DepegSwap storage ds;

        _getLatestApplicableRateAndUpdate(self);

        (dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates, ds) = previewRepurchase(self, amount);

        // decrease PSM balance
        // we also include the fee here to separate the accumulated fee from the repurchase
        self.psm.balances.paBalance -= (receivedPa);
        self.psm.balances.dsBalance -= (receivedDs);

        // transfer user RA to the PSM/LV
        self.psm.balances.ra.lockFrom(amount, buyer);

        // decrease the locked balance with the fee(if any), since the fee is used to provide liquidity
        if (fee != 0) {
            self.psm.balances.ra.decLocked(fee);
        }

        // transfer user attrubuted DS + PA
        // PA
        (, address pa) = self.info.underlyingAsset();
        IERC20(pa).safeTransfer(buyer, receivedPa);

        // DS
        IERC20(ds._address).safeTransfer(buyer, receivedDs);

        if (fee != 0) {
            uint256 remainingFee = _attributeFeeToTreasury(self, fee, treasury);
            // Provide liquidity with the remaining fee(if any)
            VaultLibrary.allocateFeesToVault(self, remainingFee);
        }
    }

    function _attributeFeeToTreasury(State storage self, uint256 fee, address treasury)
        internal
        returns (uint256 remaining)
    {
        uint256 attributedToTreasury;

        (remaining, attributedToTreasury) = _splitFee(self.psm.repurchaseFeeTreasurySplitPercentage, fee);
        self.psm.balances.ra.unlockToUnchecked(attributedToTreasury, treasury);
    }

    function _splitFee(uint256 basePercentage, uint256 fee)
        internal
        pure
        returns (uint256 remaining, uint256 splitted)
    {
        splitted = MathHelper.calculatePercentageFee(basePercentage, fee);
        remaining = fee - splitted;
    }

    function _redeemDs(Balances storage self, uint256 pa, uint256 ds) internal {
        self.dsBalance += ds;
        self.paBalance += pa;
    }

    function _afterRedeemWithDs(
        State storage self,
        DepegSwap storage ds,
        address owner,
        uint256 raReceived,
        uint256 paProvided,
        uint256 dsProvided,
        uint256 fee,
        address treasury
    ) internal {
        IERC20(ds._address).safeTransferFrom(owner, address(this), dsProvided);
        IERC20(self.info.peggedAsset().asErc20()).safeTransferFrom(owner, address(this), paProvided);

        self.psm.balances.ra.unlockTo(owner, raReceived);
        // we decrease the locked value, as we're going to use this to provide liquidity to the LV
        self.psm.balances.ra.decLocked(fee);

        uint256 attributedToTreasury;
        (fee, attributedToTreasury) = _splitFee(self.psm.psmBaseFeeTreasurySplitPercentage, fee);

        VaultLibrary.allocateFeesToVault(self, fee);
        self.psm.balances.ra.unlockToUnchecked(attributedToTreasury, treasury);
    }

    function valueLocked(State storage self, bool ra) external view returns (uint256) {
        if (ra) {
            return self.psm.balances.ra.locked;
        } else {
            return self.psm.balances.paBalance;
        }
    }

    function valueLocked(State storage self, uint256 dsId, bool ra) external view returns (uint256) {
        PsmPoolArchive storage archive = self.psm.poolArchive[dsId];

        if (ra) {
            return archive.raAccrued;
        } else {
            return archive.paAccrued;
        }
    }

    function exchangeRate(State storage self) external view returns (uint256 rates) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        rates = _getLatestApplicableRate(self);
    }

    /// @notice redeem an RA with DS + PA
    /// @dev since we currently have no way of knowing if the PA contract implements permit,
    /// we depends on the frontend to make approval to the PA contract before calling this function.
    /// for the DS, we use the permit function to approve the transfer. the parameter passed here MUST be the same
    /// as the one used to generate the ds permit signature
    function redeemWithDs(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes calldata rawDsPermitSig,
        uint256 deadline,
        address treasury
    ) external returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsProvided) {
        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }

        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        _getLatestApplicableRateAndUpdate(self);

        (received, dsProvided, fee, _exchangeRate) = previewRedeemWithDs(self, dsId, amount);

        if (received > self.psm.balances.ra.locked) {
            revert IErrors.InsufficientLiquidity(self.psm.balances.ra.locked, received);
        }

        if (deadline != 0 && rawDsPermitSig.length != 0) {
            DepegSwapLibrary.permit(
                ds._address, rawDsPermitSig, owner, address(this), dsProvided, deadline, "redeemRaWithDsPa"
            );
        }

        _redeemDs(self.psm.balances, amount, dsProvided);
        _afterRedeemWithDs(self, ds, owner, received, amount, dsProvided, fee, treasury);
    }

    /// @notice simulate a ds redeem.
    /// @return ra how much RA the user would receive
    function previewRedeemWithDs(State storage self, uint256 dsId, uint256 amount)
        public
        view
        returns (uint256 ra, uint256 ds, uint256 fee, uint256 exchangeRates)
    {
        DepegSwap storage _ds = self.ds[dsId];
        Guard.safeBeforeExpired(_ds);

        exchangeRates = _getLatestApplicableRate(self);
        // the amount here is the PA amount
        amount = TransferHelper.tokenNativeDecimalsToFixed(amount, self.info.pa);
        uint256 raDs = MathHelper.calculateEqualSwapAmount(amount, exchangeRates);

        ds = raDs;
        ra = TransferHelper.fixedToTokenNativeDecimals(raDs, self.info.ra);

        fee = MathHelper.calculatePercentageFee(ra, self.psm.psmBaseRedemptionFeePercentage);
        ra -= fee;
    }

    /// @notice return the next depeg swap expiry
    function nextExpiry(State storage self) external view returns (uint256 expiry) {
        uint256 idx = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[idx];

        expiry = Asset(ds._address).expiry();
    }

    function _calcRedeemAmount(
        State storage self,
        uint256 amount,
        uint256 totalCtIssued,
        uint256 availableRa,
        uint256 availablePa
    ) internal view returns (uint256 accruedPa, uint256 accruedRa) {
        availablePa = TransferHelper.tokenNativeDecimalsToFixed(availablePa, self.info.pa);
        availableRa = TransferHelper.tokenNativeDecimalsToFixed(availableRa, self.info.ra);

        accruedPa = MathHelper.calculateAccrued(amount, availablePa, totalCtIssued);

        accruedRa = MathHelper.calculateAccrued(amount, availableRa, totalCtIssued);

        accruedPa = TransferHelper.fixedToTokenNativeDecimals(accruedPa, self.info.pa);
        accruedRa = TransferHelper.fixedToTokenNativeDecimals(accruedRa, self.info.ra);
    }

    function _beforeCtRedeem(
        State storage self,
        DepegSwap storage ds,
        uint256 dsId,
        uint256 amount,
        uint256 accruedPa,
        uint256 accruedRa
    ) internal {
        ds.ctRedeemed += amount;
        self.psm.poolArchive[dsId].ctAttributed -= amount;
        self.psm.poolArchive[dsId].paAccrued -= accruedPa;
        self.psm.poolArchive[dsId].raAccrued -= accruedRa;
    }

    function _afterCtRedeem(
        State storage self,
        DepegSwap storage ds,
        address owner,
        uint256 ctRedeemedAmount,
        uint256 accruedPa,
        uint256 accruedRa
    ) internal {
        ERC20Burnable(ds.ct).burnFrom(owner, ctRedeemedAmount);
        IERC20(self.info.peggedAsset().asErc20()).safeTransfer(owner, accruedPa);
        IERC20(self.info.redemptionAsset()).safeTransfer(owner, accruedRa);
    }

    /// @notice redeem accrued RA + PA with CT on expiry
    /// @dev since we currently have no way of knowing if the PA contract implements permit,
    /// we depends on the frontend to make approval to the PA contract before calling this function.
    /// for the CT, we use the permit function to approve the transfer.
    /// the parameter passed here MUST be the same as the one used to generate the ct permit signature.
    function redeemWithExpiredCt(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes calldata rawCtPermitSig,
        uint256 deadline
    ) external returns (uint256 accruedPa, uint256 accruedRa) {
        if (amount == 0) {
            revert IErrors.ZeroDeposit();
        }

        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);
        if (deadline != 0) {
            DepegSwapLibrary.permit(
                ds.ct, rawCtPermitSig, owner, address(this), amount, deadline, "redeemWithExpiredCt"
            );
        }
        _separateLiquidity(self, dsId);

        uint256 totalCtIssued = self.psm.poolArchive[dsId].ctAttributed;
        PsmPoolArchive storage archive = self.psm.poolArchive[dsId];

        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount, totalCtIssued, archive.raAccrued, archive.paAccrued);

        _beforeCtRedeem(self, ds, dsId, amount, accruedPa, accruedRa);

        _afterCtRedeem(self, ds, owner, amount, accruedPa, accruedRa);
    }

    function updatePSMBaseRedemptionFeePercentage(State storage self, uint256 newFees) external {
        if (newFees > MAX_ALLOWED_FEES) {
            revert IErrors.InvalidFees();
        }
        self.psm.psmBaseRedemptionFeePercentage = newFees;
    }
}
