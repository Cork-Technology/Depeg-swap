// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PsmLib.sol";
import "./libraries/Pair.sol";
import "./interfaces/IPSMcore.sol";
import "./libraries/State.sol";
import "./ModuleState.sol";
import "./interfaces/IRates.sol";
import "@openzeppelin/contracts/utils/Context.sol";

abstract contract PsmCore is IPSMcore, ModuleState, Context {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    function depositPsm(
        Id id,
        uint256 amount
    ) external override onlyInitialized(id) {
        State storage state = states[id];
        uint256 dsId = state.deposit(_msgSender(), amount);
        emit PsmDeposited(id, dsId, _msgSender(), amount);
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

        emit DsRedeemed(id, dsId, _msgSender(), amount);

        state.redeemWithDs(
            _msgSender(),
            amount,
            dsId,
            rawDsPermitSig,
            deadline
        );
    }

    function exchangeRate(
        Id id
    ) external view override returns (uint256 rates) {
        State storage state = states[id];
        rates = state.exchangeRate();
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
            _msgSender(),
            amount,
            dsId,
            rawCtPermitSig,
            deadline
        );

        emit CtRedeemed(id, dsId, _msgSender(), amount, accruedPa, accruedRa);
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
        (paReceived, raReceived) = state.previewRedeemWithCt(dsId, amount);
    }

    function valueLocked(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.valueLocked();
    }

    function redeemRaWithCtDs(Id id, uint256 amount) external override {
        State storage state = states[id];
        (uint256 ra, uint256 dsId, uint256 rates) = state.redeemRaWithCtDs(
            _msgSender(),
            amount
        );

        emit Cancelled(id, dsId, _msgSender(), ra, amount, rates);
    }

    function previewRedeemRaWithCtDs(
        Id id,
        uint256 amount
    ) external view override returns (uint256 ra, uint256 rates) {
        State storage state = states[id];
        (ra, , rates) = state.previewRedeemRaWithCtDs(amount);
    }
}
