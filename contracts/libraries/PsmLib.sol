// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./../Asset.sol";
import "./Pair.sol";
import "./DepegSwapLib.sol";
import "./WrappedAssetLib.sol";
import "./SignatureHelperLib.sol";
import "./PeggedAssetLib.sol";
import "./RedemptionAssetLib.sol";
import "./State.sol";
import "./Guard.sol";

// TODO : support native token
// TODO : make an entrypoint that does not depend on permit
// TODO : make every redeem have receiver address
library PsmLibrary {
    using MinimalSignatureHelper for Signature;
    using PairLibrary for Pair;
    using DepegSwapLibrary for DepegSwap;
    using WrappedAssetLibrary for WrappedAssetInfo;
    using PeggedAssetLibrary for PeggedAsset;
    using RedemptionAssetLibrary for RedemptionAsset;

    function isInitialized(
        State storage self
    ) internal view returns (bool status) {
        status = self.info.isInitialized();
    }

    function initialize(
        State storage self,
        Pair memory key,
        address wa
    ) internal {
        self.info = key;
        self.psmBalances.wa = WrappedAssetLibrary.initialize(wa);
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

        self.psmBalances.wa.lockFrom(amount, depositor);
        ds.issue(depositor, amount);
    }

    /// @notice preview deposit
    /// @dev since we mint 1:1, we return the same amount,
    /// since rate only effective when redeeming with CT
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
        ctReceived = amount;
        dsReceived = amount;
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

        self.psmBalances.wa.unlockTo(amount, owner);
    }

    function valueLocked(State storage self) internal view returns (uint256) {
        return self.psmBalances.wa.locked;
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
    function previewRedeemWithDs(
        State storage self,
        uint256 dsId,
        uint256 amount
    ) internal view returns (uint256 assets) {
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);
        assets = amount;
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

    /// @notice calculate the accrued RA
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the PSM.
    ///
    /// amount * (&RA-#WA)/#CT)
    function calculateAccruedRa(
        uint256 amount,
        uint256 availableRa,
        uint256 totalWa,
        uint256 totalCtIssued
    ) internal pure returns (uint256 accrued) {
        accrued = amount * ((availableRa - totalWa) / totalCtIssued);
    }

    /// @notice calculate the accrued PA
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the PSM.
    ///
    /// amount * (&PA/#CT)
    function calculateAccruedPa(
        uint256 amount,
        uint256 availablePa,
        uint256 totalCtIssued
    ) internal pure returns (uint256 accrued) {
        accrued = amount * (availablePa / totalCtIssued);
    }

    function _calcRedeemAmount(
        State storage self,
        uint256 amount,
        uint256 totalCtIssued
    ) internal view returns (uint256 accruedPa, uint256 accruedRa) {
        uint256 availablePa = self.psmBalances.paBalance;
        accruedPa = calculateAccruedPa(amount, availablePa, totalCtIssued);

        uint256 availableRa = self.info.redemptionAsset().psmBalance();
        uint256 totalWa = self.psmBalances.wa.circulatingSupply();
        accruedRa = calculateAccruedRa(
            amount,
            availableRa,
            totalWa,
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
        self.raBalance -= accruedRa;
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
        self.info.redemptionAsset().asErc20().transfer(owner, accruedRa);
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
        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount, totalCtIssued);
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
        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount, totalCtIssued);
    }
}
