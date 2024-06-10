// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/VaultLib.sol";
import "./libraries/Pair.sol";
import "./libraries/State.sol";
import "./ModuleState.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IVault.sol";

// TODO : add events and interfaces
abstract contract VaultCore is ModuleState, Context, IVault {
    using PairLibrary for Pair;
    using VaultLibrary for State;

    function depositLv(Id id, uint256 amount) external override {
        State storage state = states[id];
        state.deposit(_msgSender(), amount);
        emit LvDeposited(id, _msgSender(), amount);
    }

    function previewLvDeposit(
        uint256 amount
    ) external pure override returns (uint256 lv) {
        lv = VaultLibrary.previewDeposit(amount);
    }

    function requestRedemption(Id id) external override {
        State storage state = states[id];
        state.requestRedemption(_msgSender());
        emit RedemptionRequested(id, _msgSender());
    }

    function transferRedemptionRights(Id id, address to) external override {
        State storage state = states[id];
        state.transferRedemptionRights(_msgSender(), to);
        emit RedemptionRightTransferred(id, _msgSender(), to);
    }

    function redeemExpiredLv(
        Id id,
        address receiver,
        uint256 amount
    ) external override {
        State storage state = states[id];
        (uint256 attributedRa, uint256 attributedPa) = state.redeemExpired(
            _msgSender(),
            receiver,
            amount
        );
        emit LvRedeemExpired(id, receiver, attributedRa, attributedPa);
    }

    function redeemEarlyLv(
        Id id,
        address receiver,
        uint256 amount
    ) external override {
        State storage state = states[id];
        state.redeemEarly(_msgSender(), receiver, amount);
        emit LvRedeemEarly(id, receiver, amount);
    }
}
