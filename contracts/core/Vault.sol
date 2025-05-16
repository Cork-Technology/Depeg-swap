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
     * @param raTolerance The tolerance for the RA
     * @param ctTolerance The tolerance for the CT
     * @param deadline The deadline for the deposit
     * @return received The amount of lv received
     */
    function depositLv(Id id, uint256 amount, uint256 raTolerance, uint256 ctTolerance, uint256 deadline)
        external
        override
        nonReentrant
        returns (uint256 received)
    {
        LVDepositNotPaused(id);
        withinDeadline(deadline);
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
        emit VaultDsSaleProfitReceived(_msgSender(), id, amount);
    }

    /**
     * Returns the amount of AMM LP tokens that the vault holds
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function vaultLp(Id id) external view returns (uint256) {
        return states[id].vaultLp(getAmmRouter());
    }

    function lvAcceptRolloverProfit(Id id, uint256 amount) external {
        onlyFlashSwapRouter();
        State storage state = states[id];
        state.allocateFeesToVault(amount);
    }

    function updateCtHeldPercentage(Id id, uint256 ctHeldPercentage) external {
        onlyConfig();
        states[id].updateCtHeldPercentage(ctHeldPercentage);
    }

    function requestLiquidationFunds(Id id, uint256 amount) external override {
        onlyWhiteListedLiquidationContract();
        State storage state = states[id];
        state.requestLiquidationFunds(amount, _msgSender());
        emit LiquidationFundsRequested(id, _msgSender(), amount);
    }

    function receiveTradeExecuctionResultFunds(Id id, uint256 amount) external override {
        State storage state = states[id];
        state.receiveTradeExecuctionResultFunds(amount, _msgSender());
        emit TradeExecutionResultFundsReceived(id, _msgSender(), amount);
    }

    function useTradeExecutionResultFunds(Id id) external override {
        onlyConfig();
        State storage state = states[id];
        uint256 used = state.useTradeExecutionResultFunds(getRouterCore(), getAmmRouter());
        emit TradeExecutionResultFundsUsed(id, _msgSender(), used);
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

    function updateVaultNavThreshold(Id id, uint256 newNavThreshold) external override {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];
        VaultLibrary.updateNavThreshold(state, newNavThreshold);
        emit VaultNavThresholdUpdated(id, newNavThreshold);
    }

    function forceUpdateNavCircuitBreakerReferenceValue(Id id) external {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];
        state.forceUpdateNavCircuitBreakerReferenceValue(getRouterCore(), getAmmRouter(), state.globalAssetIdx);
    }
}
