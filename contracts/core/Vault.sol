pragma solidity 0.8.24;

import {VaultLibrary} from "../libraries/VaultLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {State} from "../libraries/State.sol";
import {ModuleState} from "./ModuleState.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IVault} from "../interfaces/IVault.sol";

/**
 * @title VaultCore Abstract Contract
 * @author Cork Team
 * @notice Abstract VaultCore contract which provides Vault related logics
 */
abstract contract VaultCore is ModuleState, Context, IVault {
    using PairLibrary for Pair;
    using VaultLibrary for State;

    function reservedUserWithdrawal(Id id) external view override returns (uint256 reservedRa, uint256 reservedPa) {
        State storage state = states[id];
        (reservedRa, reservedPa) = state.reservedForWithdrawal();
    }

    function depositLv(Id id, uint256 amount) external override LVDepositNotPaused(id) {
        State storage state = states[id];
        state.deposit(_msgSender(), amount, getRouterCore(), getAmmRouter());
        emit LvDeposited(id, _msgSender(), amount);
    }

    function lockedLvfor(Id id, address user) external view returns (uint256 locked) {
        State storage state = states[id];
        locked = state.lvLockedFor(user);
    }

    function previewLvDeposit(Id id, uint256 amount)
        external
        view
        override
        LVDepositNotPaused(id)
        returns (uint256 lv)
    {
        lv = VaultLibrary.previewDeposit(amount);
    }

    function requestRedemption(Id id, uint256 amount, bytes memory rawLvPermitSig, uint256 deadline)
        external
        override
        LVWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        state.requestRedemption(_msgSender(), amount, rawLvPermitSig, deadline);
        emit RedemptionRequested(id, _msgSender(), amount);
    }

    function requestRedemption(Id id, uint256 amount) external override LVWithdrawalNotPaused(id) {
        State storage state = states[id];
        state.requestRedemption(_msgSender(), amount, bytes(""), 0);
        emit RedemptionRequested(id, _msgSender(), amount);
    }

    function transferRedemptionRights(Id id, address to, uint256 amount) external override {
        State storage state = states[id];
        state.transferRedemptionRights(_msgSender(), to, amount);
        emit RedemptionRightTransferred(id, _msgSender(), to, amount);
    }

    function redeemExpiredLv(Id id, address receiver, uint256 amount, bytes memory rawLvPermitSig, uint256 deadline)
        external
        override
        nonReentrant
        LVWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        (uint256 attributedRa, uint256 attributedPa) = state.redeemExpired(
            _msgSender(), receiver, amount, getAmmRouter(), getRouterCore(), rawLvPermitSig, deadline
        );
        emit LvRedeemExpired(id, receiver, attributedRa, attributedPa);
    }

    function redeemExpiredLv(Id id, address receiver, uint256 amount)
        external
        override
        nonReentrant
        LVWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        (uint256 attributedRa, uint256 attributedPa) =
            state.redeemExpired(_msgSender(), receiver, amount, getAmmRouter(), getRouterCore(), bytes(""), 0);
        emit LvRedeemExpired(id, receiver, attributedRa, attributedPa);
    }

    function previewRedeemExpiredLv(Id id, uint256 amount)
        external
        view
        override
        LVWithdrawalNotPaused(id)
        returns (uint256 attributedRa, uint256 attributedPa, uint256 approvedAmount)
    {
        State storage state = states[id];
        (attributedRa, attributedPa, approvedAmount) = state.previewRedeemExpired(amount, _msgSender(), getRouterCore());
    }

    function redeemEarlyLv(Id id, address receiver, uint256 amount, bytes memory rawLvPermitSig, uint256 deadline)
        external
        override
        nonReentrant
        LVWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        (uint256 received, uint256 fee, uint256 feePrecentage) =
            state.redeemEarly(_msgSender(), receiver, amount, getRouterCore(), getAmmRouter(), rawLvPermitSig, deadline);

        emit LvRedeemEarly(id, _msgSender(), receiver, received, fee, feePrecentage);
    }

    function redeemEarlyLv(Id id, address receiver, uint256 amount)
        external
        override
        nonReentrant
        LVWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        (uint256 received, uint256 fee, uint256 feePrecentage) =
            state.redeemEarly(_msgSender(), receiver, amount, getRouterCore(), getAmmRouter(), bytes(""), 0);

        emit LvRedeemEarly(id, _msgSender(), receiver, received, fee, feePrecentage);
    }

    function previewRedeemEarlyLv(Id id, uint256 amount)
        external
        view
        override
        LVWithdrawalNotPaused(id)
        returns (uint256 received, uint256 fee, uint256 feePrecentage)
    {
        State storage state = states[id];
        (received, fee, feePrecentage) = state.previewRedeemEarly(amount, getRouterCore());
    }

    function earlyRedemptionFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.vault.config.fee;
    }

    /// @dev assumes that `amount` is already transferred to the vault
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external onlyFlashSwapRouter {
        State storage state = states[id];
        state.provideLiquidityWithFee(amount, getRouterCore(), getAmmRouter());
    }

    function vaultLp(Id id) external view returns (uint256) {
        return states[id].vault.config.lpBalance;
    }
}
