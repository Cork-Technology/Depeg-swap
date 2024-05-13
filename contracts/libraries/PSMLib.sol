// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./../Asset.sol";
import "./PSMKeyLib.sol";
import "./DepegSwapLib.sol";
import "./WrappedAssetLib.sol";
import "./SignatureHelperLib.sol";

library PSM {
    using MinimalSignatureHelper for Signature;
    using PsmKeyLibrary for PsmKey;
    using DepegSwapLibrary for DepegSwap;
    using WrappedAssetLibrary for WrappedAsset;

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

    function _onlyNotExpired(DepegSwap storage ds) internal view {
        if (ds.isExpired()) {
            revert Expired();
        }
    }

    function _onlyInitialized(DepegSwap storage ds) internal view {
        if (!ds.isInitialized()) {
            revert Uinitialized();
        }
    }

    function _safeBeforeInteract(DepegSwap storage ds) internal view {
        _onlyInitialized(ds);
        _onlyNotExpired(ds);
    }

    struct State {
        uint256 dsCount;
        uint256 depegCount;
        uint256 fee;
        uint256 liquidity;
        WrappedAsset wa;
        PsmKey info;
        mapping(uint256 => DepegSwap) ds;
    }

    function _isInitialized(
        State storage self
    ) internal view returns (bool status) {
        status = self.info.isInitialized();
    }

    function initialize(
        State storage self,
        PsmKey memory key,
        string memory pairname,
        uint256 initiaFee
    ) internal returns (PsmId id) {
        self.info = key;
        self.fee = initiaFee;
        self.wa = WrappedAssetLibrary.initialize(pairname);

        id = key.toId();
    }

    function issue(
        State storage self,
        uint256 expiry,
        string memory pairName
    ) internal returns (uint256 idx) {
        idx = self.depegCount++;
        self.ds[idx] = DepegSwapLibrary.initialize(pairName, expiry);
    }

    function deposit(
        State storage self,
        address depositor,
        uint256 amount,
        uint256 dsId
    ) internal {
        DepegSwap storage ds = self.ds[dsId];

        _safeBeforeInteract(ds);

        self.wa.issueAndLock(amount);
        ds.issue(depositor, amount);
    }

    /// @notice preview deposit
    /// @dev since we mint 1:1, we return the same amount,
    /// since rate only effective when redeeming with CT
    function previewDeposit(
        State storage self,
        uint256 amount,
        uint256 dsId
    ) internal view returns (uint256 ctReceived, uint256 dsReceived) {
        DepegSwap storage ds = self.ds[dsId];

        _safeBeforeInteract(ds);
        ctReceived = amount;
        dsReceived = amount;
    }

    function _redeem(DepegSwap storage ds, uint256 amount) internal {
        ds.redeemed += amount;
    }

    function _afterRedeemWithDs(
        DepegSwap storage ds,
        bytes memory rawDsPermitSig,
        address owner,
        uint256 amount,
        uint256 deadline
    ) internal {
        ds.permit(rawDsPermitSig, owner, address(this), amount, deadline);
        ds.asAsset().transferFrom(owner, address(this), amount);
    }

    /// @notice redeem an RA with DS + PA
    /// @dev since we currently have no way of knowing if the PA contract implements permit,
    /// we depends on the frontend to make approval to the PA contract before calling this function.
    /// for the DS, we use the permit function to approve the transfer.
    function redeemWithDs(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) internal {
        DepegSwap storage ds = self.ds[dsId];
        _safeBeforeInteract(ds);
        _redeem(ds, amount);
        _afterRedeemWithDs(ds, rawDsPermitSig, owner, amount, deadline);
    }

    /// @notice simulate a pds redeem.
    /// @return assets how much RA the user would receive
    /// @dev since the rate is constant at 1:1, we return the same amount,
    function previewRedeemWithDs(
        State storage self,
        uint256 dsId,
        uint256 amount
    ) internal view returns (uint256 assets) {
        DepegSwap storage ds = self.ds[dsId];
        _safeBeforeInteract(ds);
        assets = amount;
    }
}
