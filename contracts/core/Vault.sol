// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VaultLibrary} from "../libraries/VaultLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {State} from "../libraries/State.sol";
import {ModuleState} from "./ModuleState.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IVaultLiquidation} from "./../interfaces/IVaultLiquidation.sol";
/**
 * @title VaultCore Abstract Contract
 * @author Cork Team
 * @notice Abstract VaultCore contract which provides Vault related logics
 */

abstract contract VaultCore is ModuleState, Context, IVault, IVaultLiquidation {
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
        nonReentrant
        returns (uint256 received)
    {
        LVDepositNotPaused(id);
        State storage state = states[id];
        received = state.deposit(_msgSender(), amount, getRouterCore(), getAmmRouter(), raTolerance, ctTolerance);
        emit LvDeposited(id, _msgSender(), received, amount);
    }

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     * @param permitParams The object with details for permit like rawLvPermitSig(Raw signature for LV approval permit) and deadline for signature
     */
    function redeemEarlyLv(RedeemEarlyParams calldata redeemParams, PermitParams calldata permitParams)
        external
        override
        nonReentrant
        returns (IVault.RedeemEarlyResult memory result)
    {
        LVWithdrawalNotPaused(redeemParams.id);
        if (permitParams.rawLvPermitSig.length == 0 || permitParams.deadline == 0) {
            revert InvalidSignature();
        }
        ProtocolContracts memory routers = ProtocolContracts({
            flashSwapRouter: getRouterCore(),
            ammRouter: getAmmRouter(),
            withdrawalContract: getWithdrawalContract()
        });

        result = states[redeemParams.id].redeemEarly(msg.sender, redeemParams, routers, permitParams);

        emit LvRedeemEarly(
            redeemParams.id,
            _msgSender(),
            _msgSender(),
            redeemParams.amount,
            result.ctReceivedFromAmm,
            result.ctReceivedFromVault,
            result.dsReceived,
            result.paReceived,
            result.raReceivedFromAmm,
            result.raIdleReceived,
            result.withdrawalId
        );
    }

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     */
    function redeemEarlyLv(RedeemEarlyParams calldata redeemParams)
        external
        override
        nonReentrant
        returns (IVault.RedeemEarlyResult memory result)
    {
        LVWithdrawalNotPaused(redeemParams.id);
        ProtocolContracts memory routers = ProtocolContracts({
            flashSwapRouter: getRouterCore(),
            ammRouter: getAmmRouter(),
            withdrawalContract: getWithdrawalContract()
        });
        PermitParams memory permitParams = PermitParams({rawLvPermitSig: bytes(""), deadline: 0});

        result = states[redeemParams.id].redeemEarly(_msgSender(), redeemParams, routers, permitParams);

        emit LvRedeemEarly(
            redeemParams.id,
            _msgSender(),
            _msgSender(),
            redeemParams.amount,
            result.ctReceivedFromAmm,
            result.ctReceivedFromVault,
            result.dsReceived,
            result.paReceived,
            result.raReceivedFromAmm,
            result.raIdleReceived,
            result.withdrawalId
        );
    }

    /**
     * This will accure value for LV holders by providing liquidity to the AMM using the RA received from selling DS when a users buys DS
     * @param id the id of the pair
     * @param amount the amount of RA received from selling DS
     * @dev assumes that `amount` is already transferred to the vault
     */
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external {
        onlyFlashSwapRouter();
        State storage state = states[id];
        state.allocateFeesToVault(amount);
        emit ProfitReceived(msg.sender, amount);
    }

    /**
     * Returns the amount of AMM LP tokens that the vault holds
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function vaultLp(Id id) external view returns (uint256) {
        return states[id].vaultLp(getAmmRouter());
    }

    /**
     * @notice Accepts rollover profit for a given ID and allocates the fees to the vault.
     * @dev This function can only be called by the FlashSwapRouter.
     * @param id The identifier for the state.
     * @param amount The amount of profit to be allocated to the vault.
     */
    function lvAcceptRolloverProfit(Id id, uint256 amount) external {
        onlyFlashSwapRouter();
        State storage state = states[id];
        state.allocateFeesToVault(amount);
    }

    /**
     * @notice Updates the collateral held percentage for a given ID.
     * @dev This function can only be called by the configuration contract.
     * @param id The identifier for which the collateral held percentage is being updated.
     * @param ctHeldPercentage The new collateral held percentage to be set.
     */
    function updateCtHeldPercentage(Id id, uint256 ctHeldPercentage) external {
        onlyConfig();
        states[id].updateCtHeldPercentage(ctHeldPercentage);
    }

    /**
     * @notice Requests liquidation funds for a given ID.
     * @dev This function can only be called by whitelisted liquidation contracts.
     * @param id The identifier for which liquidation funds are requested.
     * @param amount The amount of funds requested for liquidation.
     */
    function requestLiquidationFunds(Id id, uint256 amount) external override {
        onlyWhiteListedLiquidationContract();
        State storage state = states[id];
        state.requestLiquidationFunds(amount, msg.sender);
        emit LiquidationFundsRequested(id, msg.sender, amount);
    }

    /**
     * @notice Receives the result funds from a trade execution.
     * @dev This function is called to update the state with the funds received from a trade execution.
     * @param id The identifier of the trade.
     * @param amount The amount of funds received from the trade execution.
     */
    function receiveTradeExecuctionResultFunds(Id id, uint256 amount) external override {
        State storage state = states[id];
        state.receiveTradeExecuctionResultFunds(amount, msg.sender);
        emit TradeExecutionResultFundsReceived(id, msg.sender, amount);
    }

    /**
     * @notice Uses the trade execution result funds for a given trade identified by `id`.
     * @dev This function can only be called by the contract configuration.
     * @param id The identifier of the trade whose execution result funds are to be used.
     */
    function useTradeExecutionResultFunds(Id id) external override {
        onlyConfig();
        State storage state = states[id];
        uint256 used = state.useTradeExecutionResultFunds(getRouterCore(), getAmmRouter());
        emit TradeExecutionResultFundsUsed(id, msg.sender, used);
    }

    function liquidationFundsAvailable(Id id) external view returns (uint256) {
        return states[id].liquidationFundsAvailable();
    }

    function tradeExecutionFundsAvailable(Id id) external view returns (uint256) {
        return states[id].tradeExecutionFundsAvailable();
    }

    function lvAsset(Id id) external view override returns (address lv) {
        lv = states[id].vault.lv._address;
    }

    function totalRaAt(Id id, uint256 dsId) external view override returns (uint256) {
        return states[id].vault.totalRaSnapshot[dsId];
    }

    function receiveLeftoverFunds(Id id, uint256 amount) external override {
        states[id].receiveLeftoverFunds(amount, _msgSender());
    }

    /**
     * @notice Updates the NAV (Net Asset Value) threshold for a specific vault.
     * @dev This function can only be called by an authorized configuration role and for an initialized vault.
     * @param id The identifier of the vault whose NAV threshold is to be updated.
     * @param newNavThreshold The new NAV threshold value to be set for the vault.
     */
    function updateVaultNavThreshold(Id id, uint256 newNavThreshold) external override {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];
        VaultLibrary.updateNavThreshold(state, newNavThreshold);
        emit VaultNavThresholdUpdated(id, newNavThreshold);
    }

    /**
     * @notice Forces an update to the NAV circuit breaker reference value for a given ID.
     * @dev This function can only be called by the configuration contract and for an initialized ID.
     * @param id The identifier for which the NAV circuit breaker reference value needs to be updated.
     */
    function forceUpdateNavCircuitBreakerReferenceValue(Id id) external {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];
        state.forceUpdateNavCircuitBreakerReferenceValue(getRouterCore(), getAmmRouter(), state.globalAssetIdx);
    }
}
