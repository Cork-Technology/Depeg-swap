// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./../Asset.sol";
import "./Pair.sol";
import "./DepegSwapLib.sol";
import "./RedemptionAssetManagerLib.sol";
import "./SignatureHelperLib.sol";
import "./PeggedAssetLib.sol";
import "./State.sol";
import "./Guard.sol";
import "./MathHelper.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// TODO : support native token
// TODO : make an entrypoint that does not depend on permit
// TODO : make every redeem have receiver address
library PsmLibrary {
    using MinimalSignatureHelper for Signature;
    using PairLibrary for Pair;
    using DepegSwapLibrary for DepegSwap;
    using RedemptionAssetManagerLibrary for RedemptionAssetManager;
    using PeggedAssetLibrary for PeggedAsset;

    function isInitialized(
        State storage self
    ) internal view returns (bool status) {
        status = self.info.isInitialized();
    }

    function initialize(State storage self, Pair memory key) internal {
        self.info = key;
        self.psmBalances.ra = RedemptionAssetManagerLibrary.initialize(
            key.redemptionAsset()
        );
    }

    /// @notice issue a new pair of DS, will fail if the previous DS isn't yet expired
    function issueNewPair(
        State storage self,
        address ct,
        address ds,
        uint256 idx,
        uint256 prevIdx
    ) internal {
        if (prevIdx != 0) {
            DepegSwap storage _prevDs = self.ds[prevIdx];
            Guard.safeAfterExpired(_prevDs);
        }

        self.ds[idx] = DepegSwapLibrary.initialize(ds, ct);
    }

    /// @notice deposit RA to the PSM
    /// @dev the user must approve the PSM to spend their RA
    function deposit(
        State storage self,
        address depositor,
        uint256 amount
    ) internal returns (uint256 dsId) {
        dsId = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);

        uint256 normalizedRateAmount = MathHelper
            .calculateDepositAmountWithExchangeRate(amount, ds.exchangeRate());

        self.psmBalances.totalCtIssued += normalizedRateAmount;

        self.psmBalances.ra.lockFrom(amount, depositor);

        ds.issue(depositor, normalizedRateAmount);
    }

    /// @notice preview deposit
    /// @dev since we mint 1:1, we return the same amount,
    /// since rate only effective when redeeming with CT
    // TODO: test this
    function previewDeposit(
        State storage self,
        uint256 amount
    )
        internal
        view
        returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId)
    {
        dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
        uint256 normalizedRateAmount = MathHelper
            .calculateDepositAmountWithExchangeRate(amount, ds.exchangeRate());

        ctReceived = normalizedRateAmount;
        dsReceived = normalizedRateAmount;
    }

    function previewRedeemRaWithCtDs(
        State storage self,
        uint256 amount
    ) internal view returns (uint256 ra, uint256 dsId, uint256 rates) {
        dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        rates = ds.exchangeRate();
        ra = MathHelper.calculateRedeemAmountWithExchangeRate(amount, rates);
    }

    function redeemRaWithCtDs(
        State storage self,
        address owner,
        uint256 amount
    ) internal returns (uint256 ra, uint256 dsId, uint256 rates) {
        dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        rates = ds.exchangeRate();

        ra = MathHelper.calculateRedeemAmountWithExchangeRate(amount, rates);

        self.psmBalances.totalCtIssued -= amount;

        self.psmBalances.ra.unlockTo(owner, ra);

        ERC20Burnable(ds.ct).burnFrom(owner, amount);
        ERC20Burnable(ds.ds).burnFrom(owner, amount);
    }

    function _redeemDs(
        Balances storage self,
        DepegSwap storage ds,
        uint256 amount
    ) internal {
        self.dsBalance += amount;
        self.paBalance += amount;
        ds.dsRedeemed += amount;
    }

    function _afterRedeemWithDs(
        State storage self,
        DepegSwap storage ds,
        bytes memory rawDsPermitSig,
        address owner,
        uint256 amount,
        uint256 deadline
    ) internal {
        DepegSwapLibrary.permit(
            ds.ds,
            rawDsPermitSig,
            owner,
            address(this),
            amount,
            deadline
        );

        IERC20(ds.ds).transferFrom(owner, address(this), amount);
        self.info.peggedAsset().asErc20().transferFrom(
            owner,
            address(this),
            amount
        );

        uint256 normalizedRateAmount = MathHelper
            .calculateRedeemAmountWithExchangeRate(amount, ds.exchangeRate());

        self.psmBalances.ra.unlockTo(owner, normalizedRateAmount);
    }

    function valueLocked(State storage self) internal view returns (uint256) {
        return self.psmBalances.ra.locked;
    }

    function exchangeRate(
        State storage self
    ) internal view returns (uint256 rates) {
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
        uint256 deadline
    ) internal {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);
        _redeemDs(self.psmBalances, ds, amount);
        _afterRedeemWithDs(self, ds, rawDsPermitSig, owner, amount, deadline);
    }

    /// @notice simulate a ds redeem.
    /// @return assets how much RA the user would receive
    /// @dev since the rate is constant at 1:1, we return the same amount,
    // TODO: test this
    function previewRedeemWithDs(
        State storage self,
        uint256 dsId,
        uint256 amount
    ) internal view returns (uint256 assets) {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        uint256 normalizedRateAmount = MathHelper
            .calculateRedeemAmountWithExchangeRate(amount, ds.exchangeRate());

        assets = normalizedRateAmount;
    }

    /// @notice return the number of redeemed RA for a particular DS
    /// @param dsId the id of the DS
    /// @return amount the number of redeemed RA
    function redeemed(
        State storage self,
        uint256 dsId
    ) external view returns (uint256 amount) {
        amount = self.ds[dsId].dsRedeemed;
    }

    /// @notice return the next depeg swap expiry
    function nextExpiry(
        State storage self
    ) internal view returns (uint256 expiry) {
        uint256 idx = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[idx];

        expiry = Asset(ds.ds).expiry();
    }

    function _calcRedeemAmount(
        State storage self,
        uint256 amount,
        uint256 totalCtIssued,
        uint256 availableRa
    ) internal view returns (uint256 accruedPa, uint256 accruedRa) {
        uint256 availablePa = self.psmBalances.paBalance;
        accruedPa = MathHelper.calculateAccrued(
            amount,
            availablePa,
            totalCtIssued
        );

        accruedRa = MathHelper.calculateAccrued(
            amount,
            availableRa,
            totalCtIssued
        );
    }

    function _beforeCtRedeem(
        Balances storage self,
        DepegSwap storage ds,
        uint256 amount,
        uint256 accruedPa,
        uint256 accruedRa
    ) internal {
        ds.ctRedeemed += amount;
        self.ctBalance += amount;
        self.paBalance -= accruedPa;
        self.ra.decFree(accruedRa);
    }

    function _afterCtRedeem(
        State storage self,
        DepegSwap storage ds,
        address owner,
        uint256 ctRedeemedAmount,
        uint256 accruedPa,
        uint256 accruedRa,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) internal {
        DepegSwapLibrary.permit(
            ds.ct,
            rawCtPermitSig,
            owner,
            address(this),
            ctRedeemedAmount,
            deadline
        );

        IERC20(ds.ct).transferFrom(owner, address(this), ctRedeemedAmount);
        self.info.peggedAsset().asErc20().transfer(owner, accruedPa);
        IERC20(self.info.redemptionAsset()).transfer(owner, accruedRa);
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

        uint256 totalCtIssued = IERC20(ds.ct).totalSupply();
        uint256 availableRa = self.psmBalances.ra.convertAllToFree();

        (accruedPa, accruedRa) = _calcRedeemAmount(
            self,
            amount,
            totalCtIssued,
            availableRa
        );

        _beforeCtRedeem(self.psmBalances, ds, amount, accruedPa, accruedRa);
        _afterCtRedeem(
            self,
            ds,
            owner,
            amount,
            accruedPa,
            accruedRa,
            rawCtPermitSig,
            deadline
        );
    }

    /// @notice simulate a ct redeem. will fail if not expired.
    /// @return accruedPa the amount of PA the user would receive
    /// @return accruedRa the amount of RA the user would receive
    function previewRedeemWithCt(
        State storage self,
        uint256 dsId,
        uint256 amount
    ) internal view returns (uint256 accruedPa, uint256 accruedRa) {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);

        uint256 totalCtIssued = IERC20(ds.ct).totalSupply();

        uint256 availableRa = self.psmBalances.ra.tryConvertAllToFree();

        (accruedPa, accruedRa) = _calcRedeemAmount(
            self,
            amount,
            totalCtIssued,
            availableRa
        );
    }
}
