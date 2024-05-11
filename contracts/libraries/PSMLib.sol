// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./../DepegSwap.sol";
import "./../CoverToken.sol";
import "./PSMKey.sol";

library PSM {
    using PsmKeyLibrary for PsmKey;

    event Deposited(address indexed user, uint256 amount, uint256 indexed dsId);
    event Issued(
        address indexed dsAddress,
        uint256 indexed dsId,
        uint256 expiry
    );

    /// @notice depegSwap is expired
    error Expired();

    struct DepegSwap {
        address depegSwap;
        address coverToken;
        uint256 expiryTimestamp;
    }

    struct WrappedAsset {
        address asset;
    }

    struct State {
        uint256 dsCount;
        uint256 lockedWa;
        uint256 depegCount;
        uint256 fee;
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
        address wrappedAsset,
        uint256 initiaFee
    ) internal returns (PsmId id) {
        self.info = key;
        self.fee = initiaFee;
        self.wa = WrappedAsset({asset: wrappedAsset});

        id = key.toId();
    }

    function issue(
        State storage self,
        uint256 expiry,
        address ds,
        address ct
    ) internal returns (uint256 idx) {
        idx = self.depegCount++;
        self.ds[idx] = DepegSwap({
            depegSwap: ds,
            coverToken: ct,
            expiryTimestamp: expiry
        });
    }

    function deposit(uint256 amount, uint256 dsId) external {}
}
