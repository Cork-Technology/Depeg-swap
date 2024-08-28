pragma solidity 0.8.24;

import {Asset, ERC20Burnable} from "../core/assets/Asset.sol";
import {Pair, PairLibrary} from "./Pair.sol";
import {DepegSwap, DepegSwapLibrary} from "./DepegSwapLib.sol";
import {PsmRedemptionAssetManager, RedemptionAssetManagerLibrary} from "./RedemptionAssetManagerLib.sol";
import {Signature, MinimalSignatureHelper} from "./SignatureHelperLib.sol";
import {PeggedAsset, PeggedAssetLibrary} from "./PeggedAssetLib.sol";
import {State, BitMaps, Balances, PsmPoolArchive} from "./State.sol";
import {Guard} from "./Guard.sol";
import {MathHelper} from "./MathHelper.sol";
import {IRepurchase} from "../interfaces/IRepurchase.sol";
import {ICommon} from "../interfaces/ICommon.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {VaultLibrary} from "./VaultLib.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap-v2/RouterV2.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Psm Library Contract
 * @author Cork Team
 * @notice Psm Library implements functions for PSM Core contract
 */
library PsmLibrary {
    using MinimalSignatureHelper for Signature;
    using PairLibrary for Pair;
    using DepegSwapLibrary for DepegSwap;
    using RedemptionAssetManagerLibrary for PsmRedemptionAssetManager;
    using PeggedAssetLibrary for PeggedAsset;
    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;

    function isInitialized(State storage self) internal view returns (bool status) {
        status = self.info.isInitialized();
    }

    function initialize(State storage self, Pair memory key) internal {
        self.info = key;
        self.psm.balances.ra = RedemptionAssetManagerLibrary.initialize(key.redemptionAsset());
    }

    /// @notice issue a new pair of DS, will fail if the previous DS isn't yet expired
    function onNewIssuance(
        State storage self,
        address ct,
        address ds,
        address ammPair,
        uint256 idx,
        uint256 prevIdx,
        uint256 repurchaseFeePercent
    ) internal {
        if (prevIdx != 0) {
            DepegSwap storage _prevDs = self.ds[prevIdx];
            Guard.safeAfterExpired(_prevDs);
            _separateLiquidity(self, prevIdx);
        }

        // essentially burn unpurchased ds as we're going in with a new issuance
        self.psm.balances.dsBalance = 0;

        self.psm.repurchaseFeePrecentage = repurchaseFeePercent;
        self.ds[idx] = DepegSwapLibrary.initialize(ds, ct, ammPair);
    }

    function _separateLiquidity(State storage self, uint256 prevIdx) internal {
        if (self.psm.liquiditySeparated.get(prevIdx)) {
            return;
        }

        DepegSwap storage ds = self.ds[prevIdx];
        Guard.safeAfterExpired(ds);

        uint256 availableRa = self.psm.balances.ra.convertAllToFree();
        uint256 availablePa = self.psm.balances.paBalance;

        self.psm.poolArchive[prevIdx] = PsmPoolArchive(availableRa, availablePa, IERC20(ds.ct).totalSupply());

        // reset current balances
        self.psm.balances.ra.reset();
        self.psm.balances.paBalance = 0;

        self.psm.liquiditySeparated.set(prevIdx);
    }

    /// @notice deposit RA to the PSM
    /// @dev the user must approve the PSM to spend their RA
    function deposit(State storage self, address depositor, uint256 amount)
        internal
        returns (uint256 dsId, uint256 received, uint256 _exchangeRate)
    {
        if (amount == 0) {
            revert ICommon.ZeroDeposit();
        }

        dsId = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
        _exchangeRate = ds.exchangeRate();

        received = MathHelper.calculateDepositAmountWithExchangeRate(amount, _exchangeRate);

        self.psm.balances.ra.lockFrom(amount, depositor);

        ds.issue(depositor, received);
    }

    // This is here just for semantics, since in the whitepaper, all the CT DS issuance
    // happens in the PSM, although they essentially lives in the same contract, we leave it here just for consistency sake
    //
    // IMPORTANT/FIXME: this is unsafe because by issuing CT, we also lock an equal amount of RA into the PSM.
    // it is a must, that the LV won't count the amount being locked in the PSM as it's balances.
    // doing so would create a mismatch between the accounting balance and the actual token balance.
    function unsafeIssueToLv(State storage self, uint256 amount) internal {
        uint256 dsId = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[dsId];

        self.psm.balances.ra.incLocked(amount);

        ds.issue(address(this), amount);
    }

    function lvRedeemRaWithCtDs(State storage self, uint256 amount, uint256 dsId) internal {
        DepegSwap storage ds = self.ds[dsId];
        ds.burnBothforSelf(amount);
    }

    function lvRedeemRaPaWithCt(State storage self, uint256 amount, uint256 dsId)
        internal
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        // we separate the liquidity here, that means, LP liquidation on the LV also triggers
        _separateLiquidity(self, dsId);

        uint256 totalCtIssued = self.psm.poolArchive[dsId].ctAttributed;
        PsmPoolArchive storage archive = self.psm.poolArchive[dsId];

        (accruedPa, accruedRa) = _calcRedeemAmount(amount, totalCtIssued, archive.raAccrued, archive.paAccrued);

        _beforeCtRedeem(self, self.ds[dsId], dsId, amount, accruedPa, accruedRa);
    }

    /// @notice preview deposit
    /// @dev since we mint 1:1, we return the same amount,
    /// since rate only effective when redeeming with CT
    function previewDeposit(State storage self, uint256 amount)
        internal
        view
        returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId)
    {
        if (amount == 0) {
            revert ICommon.ZeroDeposit();
        }

        dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
        uint256 normalizedRateAmount = MathHelper.calculateDepositAmountWithExchangeRate(amount, ds.exchangeRate());

        ctReceived = normalizedRateAmount;
        dsReceived = normalizedRateAmount;
    }

    function previewRedeemRaWithCtDs(State storage self, uint256 amount)
        internal
        view
        returns (uint256 ra, uint256 dsId, uint256 rates)
    {
        dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        rates = ds.exchangeRate();
        ra = MathHelper.calculateRedeemAmountWithExchangeRate(amount, rates);
    }

    function _redeemRaWithCtDs(State storage self, DepegSwap storage ds, address owner, uint256 amount)
        internal
        returns (uint256 ra, uint256 rates)
    {
        rates = ds.exchangeRate();

        ra = MathHelper.calculateRedeemAmountWithExchangeRate(amount, rates);

        self.psm.balances.ra.unlockTo(owner, ra);

        ERC20Burnable(ds.ct).burnFrom(owner, amount);
        ERC20Burnable(ds._address).burnFrom(owner, amount);
    }

    function redeemRaWithCtDs(
        State storage self,
        address owner,
        uint256 amount,
        bytes memory rawDsPermitSig,
        uint256 dsDeadline,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) internal returns (uint256 ra, uint256 dsId, uint256 rates) {
        dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);
        if (dsDeadline != 0 && ctDeadline != 0) {
            DepegSwapLibrary.permit(ds._address, rawDsPermitSig, owner, address(this), amount, dsDeadline);
            DepegSwapLibrary.permit(ds.ct, rawCtPermitSig, owner, address(this), amount, ctDeadline);
        }

        (ra, rates) = _redeemRaWithCtDs(self, ds, owner, amount);
    }

    function availableForRepurchase(State storage self) internal view returns (uint256 pa, uint256 ds, uint256 dsId) {
        dsId = self.globalAssetIdx;
        DepegSwap storage _ds = self.ds[dsId];
        Guard.safeBeforeExpired(_ds);

        pa = self.psm.balances.paBalance;
        ds = self.psm.balances.dsBalance;
    }

    function repurchaseRates(State storage self) internal view returns (uint256 rates) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        rates = ds.exchangeRate();
    }

    function repurchaseFeePrecentage(State storage self) internal view returns (uint256 rates) {
        rates = self.psm.repurchaseFeePrecentage;
    }

    function updateRepurchaseFeePercentage(State storage self, uint256 newFees) internal {
        if (newFees > 5 ether) {
            revert ICommon.InvalidFees();
        }
        self.psm.repurchaseFeePrecentage = newFees;
    }

    function updatePoolsStatus(
        State storage self,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    ) internal {
        self.psm.isDepositPaused = isPSMDepositPaused;
        self.psm.isWithdrawalPaused = isPSMWithdrawalPaused;
        self.vault.config.isDepositPaused = isLVDepositPaused;
        self.vault.config.isWithdrawalPaused = isLVWithdrawalPaused;
    }

    function previewRepurchase(State storage self, uint256 amount)
        internal
        view
        returns (
            uint256 dsId,
            uint256 received,
            uint256 feePrecentage,
            uint256 fee,
            uint256 exchangeRates,
            DepegSwap storage ds
        )
    {
        dsId = self.globalAssetIdx;

        ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        exchangeRates = ds.exchangeRate();

        // the fee is taken directly from RA before it's even converted to DS
        feePrecentage = self.psm.repurchaseFeePrecentage;
        fee = MathHelper.calculatePrecentageFee(amount, feePrecentage);
        amount = amount - fee;

        // we use deposit here because technically the user deposit RA to the PSM when repurchasing
        received = MathHelper.calculateDepositAmountWithExchangeRate(amount, exchangeRates);

        received = received;

        uint256 available = self.psm.balances.paBalance;
        // ensure that we have an equal amount of DS and PA
        assert(available == self.psm.balances.dsBalance);

        if (received > available) {
            revert IRepurchase.InsufficientLiquidity(available, received);
        }
    }

    function repurchase(
        State storage self,
        address buyer,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter
    ) internal returns (uint256 dsId, uint256 received, uint256 feePrecentage, uint256 fee, uint256 exchangeRates) {
        DepegSwap storage ds;

        (dsId, received, feePrecentage, fee, exchangeRates, ds) = previewRepurchase(self, amount);

        // decrease PSM balance
        // we also include the fee here to separate the accumulated fee from the repurchase
        self.psm.balances.paBalance -= (received);
        self.psm.balances.dsBalance -= (received);

        // transfer user RA to the PSM/LV
        self.psm.balances.ra.lockUnchecked(amount, buyer);

        // transfer user attrubuted DS + PA
        // PA
        (, address pa) = self.info.underlyingAsset();
        IERC20(pa).safeTransfer(buyer, received);

        // DS
        IERC20(ds._address).transfer(buyer, received);

        // Provide liquidity
        VaultLibrary.provideLiquidityWithFee(self, fee, flashSwapRouter, ammRouter);
    }

    function _redeemDs(Balances storage self, uint256 amount) internal {
        self.dsBalance += amount;
        self.paBalance += amount;
    }

    function _afterRedeemWithDs(
        State storage self,
        DepegSwap storage ds,
        address owner,
        uint256 amount,
        uint256 feePrecentage
    ) internal returns (uint256 received, uint256 _exchangeRate, uint256 fee) {
        IERC20(ds._address).transferFrom(owner, address(this), amount);

        _exchangeRate = ds.exchangeRate();
        received = MathHelper.calculateRedeemAmountWithExchangeRate(amount, _exchangeRate);

        fee = MathHelper.calculatePrecentageFee(received, feePrecentage);
        received -= fee;

        IERC20(self.info.peggedAsset().asErc20()).safeTransferFrom(owner, address(this), amount);

        self.psm.balances.ra.unlockTo(owner, received);
    }

    function valueLocked(State storage self) internal view returns (uint256) {
        return self.psm.balances.ra.locked;
    }

    function exchangeRate(State storage self) internal view returns (uint256 rates) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        rates = ds.exchangeRate();
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
        bytes memory rawDsPermitSig,
        uint256 deadline,
        uint256 feePrecentage
    ) internal returns (uint256 received, uint256 _exchangeRate, uint256 fee) {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);
        if (deadline != 0) {
            DepegSwapLibrary.permit(ds._address, rawDsPermitSig, owner, address(this), amount, deadline);
        }
        _redeemDs(self.psm.balances, amount);
        (received, _exchangeRate, fee) = _afterRedeemWithDs(self, ds, owner, amount, feePrecentage);
    }

    /// @notice simulate a ds redeem.
    /// @return assets how much RA the user would receive
    function previewRedeemWithDs(State storage self, uint256 dsId, uint256 amount)
        internal
        view
        returns (uint256 assets)
    {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        uint256 normalizedRateAmount = MathHelper.calculateRedeemAmountWithExchangeRate(amount, ds.exchangeRate());

        assets = normalizedRateAmount;
    }

    /// @notice return the next depeg swap expiry
    function nextExpiry(State storage self) internal view returns (uint256 expiry) {
        uint256 idx = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[idx];

        expiry = Asset(ds._address).expiry();
    }

    function _calcRedeemAmount(uint256 amount, uint256 totalCtIssued, uint256 availableRa, uint256 availablePa)
        internal
        pure
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        accruedPa = MathHelper.calculateAccrued(amount, availablePa, totalCtIssued);

        accruedRa = MathHelper.calculateAccrued(amount, availableRa, totalCtIssued);
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
        IERC20(ds.ct).transferFrom(owner, address(this), ctRedeemedAmount);
        IERC20(self.info.peggedAsset().asErc20()).safeTransfer(owner, accruedPa);
        IERC20(self.info.redemptionAsset()).safeTransfer(owner, accruedRa);
    }

    /// @notice redeem accrued RA + PA with CT on expiry
    /// @dev since we currently have no way of knowing if the PA contract implements permit,
    /// we depends on the frontend to make approval to the PA contract before calling this function.
    /// for the CT, we use the permit function to approve the transfer.
    /// the parameter passed here MUST be the same as the one used to generate the ct permit signature.
    function redeemWithCt(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) internal returns (uint256 accruedPa, uint256 accruedRa) {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);
        if (deadline != 0) {
            DepegSwapLibrary.permit(ds.ct, rawCtPermitSig, owner, address(this), amount, deadline);
        }
        _separateLiquidity(self, dsId);

        uint256 totalCtIssued = self.psm.poolArchive[dsId].ctAttributed;
        PsmPoolArchive storage archive = self.psm.poolArchive[dsId];

        (accruedPa, accruedRa) = _calcRedeemAmount(amount, totalCtIssued, archive.raAccrued, archive.paAccrued);

        _beforeCtRedeem(self, ds, dsId, amount, accruedPa, accruedRa);

        _afterCtRedeem(self, ds, owner, amount, accruedPa, accruedRa);
    }

    /// @notice simulate a ct redeem. will fail if not expired.
    /// @return accruedPa the amount of PA the user would receive
    /// @return accruedRa the amount of RA the user would receive
    function previewRedeemWithCt(State storage self, uint256 dsId, uint256 amount)
        internal
        view
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);

        uint256 totalCtIssued = IERC20(ds.ct).totalSupply();
        uint256 availableRa = self.psm.balances.ra.tryConvertAllToFree();
        uint256 availablePa = self.psm.balances.paBalance;

        if (self.psm.liquiditySeparated.get(dsId)) {
            PsmPoolArchive storage archive = self.psm.poolArchive[dsId];
            totalCtIssued = archive.ctAttributed;
            availableRa = archive.raAccrued;
            availablePa = archive.paAccrued;
        }

        (accruedPa, accruedRa) = _calcRedeemAmount(amount, totalCtIssued, availableRa, availablePa);
    }
}
