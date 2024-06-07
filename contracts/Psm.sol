// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PsmLib.sol";
import "./libraries/Pair.sol";
import "./interfaces/IPSMcore.sol";
import "./libraries/State.sol";
import "./ModuleState.sol";

abstract contract PsmCore is IPSMcore, ModuleState {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    function depositPsm(
        Id id,
        uint256 amount
    ) external override onlyInitialized(id) {
        State storage state = states[id];
        uint256 dsId = state.deposit(msg.sender, amount);
        emit PsmDeposited(id, dsId, msg.sender, amount);
    }

    function previewDepositPsm(
        Id id,
        uint256 amount
    )
        external
        view
        override
        onlyInitialized(id)
        returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId)
    {
        State storage state = states[id];
        (ctReceived, dsReceived, dsId) = state.previewDeposit(amount);
    }

    function redeemRaWithDs(
        Id id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external override onlyInitialized(id) {
        State storage state = states[id];

        emit DsRedeemed(id, dsId, msg.sender, amount);

        state.redeemWithDs(msg.sender, amount, dsId, rawDsPermitSig, deadline);
    }

    function previewRedeemRaWithDs(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external view override onlyInitialized(id) returns (uint256 assets) {
        State storage state = states[id];
        assets = state.previewRedeemWithDs(amount, dsId);
    }

    function redeemWithCT(
        Id id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) external override onlyInitialized(id) {
        State storage state = states[id];

        (uint256 accruedPa, uint256 accruedRa) = state.redeemWithCt(
            msg.sender,
            amount,
            dsId,
            rawCtPermitSig,
            deadline
        );

        emit CtRedeemed(id, dsId, msg.sender, amount, accruedPa, accruedRa);
    }

    function previewRedeemWithCt(
        Id id,
        uint256 dsId,
        uint256 amount
    )
        external
        view
        override
        onlyInitialized(id)
        returns (uint256 paReceived, uint256 raReceived)
    {
        State storage state = states[id];
        (paReceived, raReceived) = state.previewRedeemWithCt(amount, dsId);
    }

    function valueLocked(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.valueLocked();
    }
}
