pragma solidity ^0.8.24;

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
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     * @return received The amount of lv received
     */
    function depositLv(Id id, uint256 amount, uint256 raTolerance, uint256 ctTolerance)
        external
        override
        LVDepositNotPaused(id)
        returns (uint256 received)
    {
        State storage state = states[id];
        received = state.deposit(_msgSender(), amount, getRouterCore(), getAmmRouter(), raTolerance, ctTolerance);
        emit LvDeposited(id, _msgSender(), received);
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
        returns (uint256 lv, uint256 raAddedAsLiquidity, uint256 ctAddedAsLiquidity)
    {
        (lv, raAddedAsLiquidity, ctAddedAsLiquidity) = VaultLibrary.previewDeposit(states[id], getRouterCore(), amount);
    }

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     * @param redeemer The address of the redeemer
     * @param permitParams The object with details for permit like rawLvPermitSig(Raw signature for LV approval permit) and deadline for signature
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams, address redeemer, PermitParams memory permitParams)
        external
        override
        nonReentrant
        LVWithdrawalNotPaused(redeemParams.id)
        returns (uint256 received, uint256 fee, uint256 feePercentage, uint256 paAmount)
    {
        if (permitParams.rawLvPermitSig.length == 0 || permitParams.deadline == 0) {
            revert InvalidSignature();
        }
        Routers memory routers = Routers({flashSwapRouter: getRouterCore(), ammRouter: getAmmRouter()});
        (received, fee, feePercentage, paAmount) =
            states[redeemParams.id].redeemEarly(redeemer, redeemParams, routers, permitParams);

        emit LvRedeemEarly(redeemParams.id, redeemer, redeemParams.receiver, received, fee, feePercentage);
    }

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams)
        external
        override
        nonReentrant
        LVWithdrawalNotPaused(redeemParams.id)
        returns (uint256 received, uint256 fee, uint256 feePercentage, uint256 paAmount)
    {
        Routers memory routers = Routers({flashSwapRouter: getRouterCore(), ammRouter: getAmmRouter()});
        PermitParams memory permitParams = PermitParams({rawLvPermitSig: bytes(""), deadline: 0});

        (received, fee, feePercentage, paAmount) =
            states[redeemParams.id].redeemEarly(_msgSender(), redeemParams, routers, permitParams);

        emit LvRedeemEarly(redeemParams.id, _msgSender(), redeemParams.receiver, received, fee, feePercentage);
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
        returns (uint256 received, uint256 fee, uint256 feePercentage, uint256 paAmount)
    {
        State storage state = states[id];
        (received, fee, feePercentage, paAmount) = state.previewRedeemEarly(amount, getRouterCore());
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

    function lvAcceptRolloverProfit(Id id, uint256 amount) external onlyFlashSwapRouter {
        State storage state = states[id];
        state.provideLiquidityWithFee(amount, getRouterCore(), getAmmRouter());
    }
}
