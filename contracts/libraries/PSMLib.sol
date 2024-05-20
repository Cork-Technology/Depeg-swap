// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./../Asset.sol";
import "./PSMKeyLib.sol";
import "./DepegSwapLib.sol";
import "./WrappedAssetLib.sol";
import "./SignatureHelperLib.sol";
import "./PeggedAssetLib.sol";
import "./RedemptionAssetLib.sol";

struct State {
    uint256 dsCount;
    uint256 totalCtIssued;
    WrappedAsset wa;
    PsmKey info;
    mapping(uint256 => DepegSwap) ds;
}

// TODO : support native token
library PSMLibrary {
    using MinimalSignatureHelper for Signature;
    using PsmKeyLibrary for PsmKey;
    using DepegSwapLibrary for DepegSwap;
    using WrappedAssetLibrary for WrappedAsset;
    using PeggedAssetLibrary for PeggedAsset;
    using RedemptionAssetLibrary for RedemptionAsset;

    event Deposited(address indexed user, uint256 amount, uint256 indexed dsId);
    event Issued(
        address indexed dsAddress,
        uint256 indexed dsId,
        uint256 expiry
    );

    /// @notice depegSwap is expired
    error Expired();

    /// @notice depegSwap is not initialized
    error Uinitialized();

    /// @notice depegSwap is not expired. e.g trying to redeem before expiry
    error NotExpired();

    function _onlyNotExpired(DepegSwap storage ds) internal view {
        if (ds.isExpired()) {
            revert Expired();
        }
    }

    function _onlyExpired(DepegSwap storage ds) internal view {
        if (!ds.isExpired()) {
            revert NotExpired();
        }
    }

    function _onlyInitialized(DepegSwap storage ds) internal view {
        if (!ds.isInitialized()) {
            revert Uinitialized();
        }
    }

    function _safeBeforeExpired(DepegSwap storage ds) internal view {
        _onlyInitialized(ds);
        _onlyNotExpired(ds);
    }

    function _safeAfterExpired(DepegSwap storage ds) internal view {
        _onlyInitialized(ds);
        _onlyExpired(ds);
    }

    function isInitialized(
        State storage self
    ) internal view returns (bool status) {
        status = self.info.isInitialized();
    }

    function initialize(
        State storage self,
        PsmKey memory key,
        string memory pairname
    ) internal {
        self.info = key;
        self.wa = WrappedAssetLibrary.initialize(pairname);
    }

    /// @notice issue a new pair of DS, will fail if the previous DS isn't yet expired
    function issueNewPair(
        State storage self,
        uint256 expiry
    ) internal returns (uint256 idx, address dsAddress, address ct) {
        if (self.dsCount != 0) {
            DepegSwap storage ds = self.ds[self.dsCount];
            _safeAfterExpired(ds);
        }

        // to prevent 0 index
        self.dsCount++;
        idx = self.dsCount;

        string memory pairName = self.info.toPairname();
        self.ds[idx] = DepegSwapLibrary.initialize(pairName, expiry);
        (dsAddress, ct) = (self.ds[idx].depegSwap, self.ds[idx].coverToken);
    }

    /// @notice deposit RA to the PSM
    /// @dev the user must approve the PSM to spend their RA
    function deposit(
        State storage self,
        address depositor,
        uint256 amount
    ) internal returns (uint256 dsId) {
        dsId = self.dsCount;

        DepegSwap storage ds = self.ds[dsId];

        _safeBeforeExpired(ds);

        // add the amount to the total ct issued
        self.totalCtIssued += amount;

        self.wa.issueAndLock(amount);
        self.info.redemptionAsset().asErc20().transferFrom(depositor, address(this), amount);
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
        dsId = self.dsCount;
        DepegSwap storage ds = self.ds[dsId];

        _safeBeforeExpired(ds);
        ctReceived = amount;
        dsReceived = amount;
    }

    function _redeemDs(DepegSwap storage ds, uint256 amount) internal {
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
            ds.depegSwap,
            rawDsPermitSig,
            owner,
            address(this),
            amount,
            deadline
        );
        ds.dsAsAsset().transferFrom(owner, address(this), amount);
        self.info.redemptionAsset().asErc20().transfer(owner, amount);
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
        _safeBeforeExpired(ds);
        _redeemDs(ds, amount);
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
        _safeBeforeExpired(ds);
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
        uint256 idx = self.dsCount;

        DepegSwap storage ds = self.ds[idx];

        expiry = ds.expiryTimestamp;
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
        uint256 amount
    ) internal view returns (uint256 accruedPa, uint256 accruedRa) {
        uint256 totalCtIssued = self.totalCtIssued;

        uint256 availablePa = self.info.peggedAsset().psmBalance();
        accruedPa = calculateAccruedPa(amount, availablePa, totalCtIssued);

        uint256 availableRa = self.info.redemptionAsset().psmBalance();
        uint256 totalWa = self.wa.circulatingSupply();
        accruedRa = calculateAccruedRa(
            amount,
            availableRa,
            totalWa,
            totalCtIssued
        );
    }

    function _incRedeemedCt(DepegSwap storage ds, uint256 amount) internal {
        ds.ctRedeemed += amount;
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
            ds.coverToken,
            rawCtPermitSig,
            owner,
            address(this),
            ctRedeemedAmount,
            deadline
        );

        ds.ctAsAsset().transferFrom(owner, address(this), ctRedeemedAmount);
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
        _safeAfterExpired(ds);

        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount);
        _incRedeemedCt(ds, amount);
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
        _safeAfterExpired(ds);

        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount);
    }
}
