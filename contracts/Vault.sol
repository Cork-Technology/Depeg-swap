// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/VaultLib.sol";
import "./libraries/PairKey.sol";
import "./libraries/State.sol";
import "./ModuleState.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IVault.sol";

// TODO : add events and interfaces
abstract contract VaultCore is ModuleState, Context, IVault {
    using PairKeyLibrary for PairKey;
    using VaultLibrary for State;

    function depositLv(
        ModuleId id,
        uint256 amount
    ) external override {
        State storage state = states[id];
        state.deposit(_msgSender(), amount);
        emit LvDeposited(id, _msgSender(), amount);
    }

    function previewLvDeposit(uint256 amount) external override pure returns (uint256 lv) {
        lv = VaultLibrary.previewDeposit(amount);
    }

    function requestRedemption(ModuleId id) external override {
        State storage state = states[id];
        state.requestRedemption(_msgSender());
        emit RedemptionRequested(id, _msgSender());
    }

    function transferRedemptionRights(
        ModuleId id,
        address to
    ) external override {
        State storage state = states[id];
        state.transferRedemptionRights(_msgSender(), to);
        emit RedemptionRightTransferred(id, _msgSender(), to);
    }

    function redeemExpiredLv(
        ModuleId id,
        address receiver,
        uint256 amount
    ) external override {
        State storage state = states[id];
        state.redeemExpired(_msgSender(), receiver, amount);
        emit LvRedeemExpired(id, receiver, amount);
    }

    function redeemEarlyLv(
        ModuleId id,
        address receiver,
        uint256 amount
    ) external override{
        State storage state = states[id];
        state.redeemEarly(_msgSender(), receiver, amount);
        emit LvRedeemEarly(id, receiver, amount);
    }
}
