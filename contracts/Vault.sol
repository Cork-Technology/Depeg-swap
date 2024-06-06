// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/VaultLib.sol";
import "./libraries/PairKey.sol";
import "./libraries/State.sol";
import "./ModuleState.sol";
import "@openzeppelin/contracts/utils/Context.sol";

// TODO : add events and interfaces
abstract contract VaultCore is ModuleState, Context {
    using PairKeyLibrary for PairKey;
    using VaultLibrary for State;

    function depositLv(ModuleId id, address from, uint256 amount) external {
        State storage state = states[id];
        state.deposit(from, amount);
        // TODO emit event
    }

    function previewDeposit(uint256 amount) external pure returns (uint256 lv) {
        lv = VaultLibrary.previewDeposit(amount);
    }

    function requestRedemption(ModuleId id) external {
        State storage state = states[id];
        state.requestRedemption(_msgSender());
        // TODO emit event
    }

    function transferRedemptionRights(ModuleId id, address to) external {
        State storage state = states[id];
        state.transferRedemptionRights(_msgSender(), to);
        // TODO emit event
    }

    function redeemExpiredLv(address receiver, uint256 amount) external {
        State storage state = states[
            PairKeyLibrary.initalize(address(0), address(0)).toId()
        ];
        state.redeemExpired(_msgSender(), receiver, amount);
        // TODO emit event
    }

    function redeemEarlyLv(
        ModuleId id,
        address receiver,
        uint256 amount
    ) external {
        State storage state = states[id];
        state.redeemEarly(_msgSender(), receiver, amount);
        // TODO emit event
    }
}
