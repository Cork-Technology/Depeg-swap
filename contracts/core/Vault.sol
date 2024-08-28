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

    /**
     * Returns the amount of RA and PA reserved for user withdrawal
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function reservedUserWithdrawal(Id id) external view override returns (uint256 reservedRa, uint256 reservedPa) {
        State storage state = states[id];
        (reservedRa, reservedPa) = state.reservedForWithdrawal();
    }

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     */
    function depositLv(Id id, uint256 amount) external override LVDepositNotPaused(id) {
        State storage state = states[id];
        state.deposit(_msgSender(), amount, getRouterCore(), getAmmRouter());
        emit LvDeposited(id, _msgSender(), amount);
    }

    /**
     * @notice Get the amount of locked lv for a given user
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param user The address of the user
     */
    function lockedLvfor(Id id, address user) external view returns (uint256 locked) {
        State storage state = states[id];
        locked = state.lvLockedFor(user);
    }

    /**
     * @notice Preview the amount of lv that will be deposited
     * @param amount The amount of the redemption asset(ra) to be deposited
     */
    function previewLvDeposit(Id id, uint256 amount)
        external
        view
        override
        LVDepositNotPaused(id)
        returns (uint256 lv)
    {
        lv = VaultLibrary.previewDeposit(amount);
    }

    /**
     * @notice Request redemption of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param rawLvPermitSig  The signature for Lv transfer permitted by user
     * @param deadline  The deadline timestamp os signature expiry
     */
    function requestRedemption(Id id, uint256 amount, bytes memory rawLvPermitSig, uint256 deadline)
        external
        override
        LVWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        state.requestRedemption(_msgSender(), amount, rawLvPermitSig, deadline);
        emit RedemptionRequested(id, _msgSender(), amount);
    }

    /**
     * @notice Request redemption of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function requestRedemption(Id id, uint256 amount) external override LVWithdrawalNotPaused(id) {
        State storage state = states[id];
        state.requestRedemption(_msgSender(), amount, bytes(""), 0);
        emit RedemptionRequested(id, _msgSender(), amount);
    }

    /**
     * @notice Transfer redemption rights of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param to The address of the new owner of the redemption rights
     * @param amount The amount of the user locked LV token to be transferred
     */
    function transferRedemptionRights(Id id, address to, uint256 amount) external override {
        State storage state = states[id];
        state.transferRedemptionRights(_msgSender(), to, amount);
        emit RedemptionRightTransferred(id, _msgSender(), to, amount);
    }

    /**
     * @notice Redeem expired lv, when there's no active DS issuance, there's no cap on the amount of lv that can be redeemed.
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver  The address of the receiver
     * @param amount The amount of the asset to be redeemed
     * @param rawLvPermitSig  The signature for Lv transfer permitted by user
     * @param deadline  The deadline timestamp os signature expiry
     */
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

    /**
     * @notice Redeem expired lv, when there's no active DS issuance, there's no cap on the amount of lv that can be redeemed.
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver  The address of the receiver
     * @param amount The amount of the asset to be redeemed
     */
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

    /**
     * @notice preview redeem expired lv
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the asset to be redeemed
     * @return attributedRa The amount of ra that will be redeemed
     * @return attributedPa The amount of pa that will be redeemed
     * @return approvedAmount The amount of lv needed to be approved before redeeming,
     * this is necessary when the user doesn't have enough locked LV token to redeem the full amount
     */
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

    /**
     * @notice Redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed
     * @param rawLvPermitSig Raw signature for LV approval permit
     * @param deadline deadline for Approval permit signature
     */
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

    /**
     * @notice Redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed
     */
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

    /**
     * @notice preview redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the asset to be redeemed
     */
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

    /**
     * Returns the early redemption fee percentage
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function earlyRedemptionFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.vault.config.fee;
    }

    /**
     * This will accure value for LV holders by providing liquidity to the AMM using the RA received from selling DS when a users buys DS
     * @param id the id of the pair
     * @param amount the amount of RA received from selling DS
     * @dev assumes that `amount` is already transferred to the vault
     */
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external onlyFlashSwapRouter {
        State storage state = states[id];
        state.provideLiquidityWithFee(amount, getRouterCore(), getAmmRouter());
    }

    /**
     * Returns the amount of AMM LP tokens that the vault holds
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function vaultLp(Id id) external view returns (uint256) {
        return states[id].vault.config.lpBalance;
    }
}
