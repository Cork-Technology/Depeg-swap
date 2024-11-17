// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PsmLibrary} from "../libraries/PsmLib.sol";
import {VaultLibrary} from "../libraries/VaultLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {IPSMcore} from "../interfaces/IPSMcore.sol";
import {State} from "../libraries/State.sol";
import {ModuleState} from "./ModuleState.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";

/**
 * @title PsmCore Abstract Contract
 * @author Cork Team
 * @notice Abstract PsmCore contract provides PSM related logics
 */
abstract contract PsmCore is IPSMcore, ModuleState, Context {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    function updateRate(Id id, uint256 newRate) external onlyConfig {
        State storage state = states[id];
        uint256 previousRate = state.exchangeRate();

        state.updateExchangeRate(newRate);

        emit RateUpdated(id, newRate, previousRate);
    }

    /**
     * @notice returns the fee percentage for repurchasing(1e18 = 1%)
     * @param id the id of PSM
     */
    function repurchaseFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.repurchaseFeePercentage();
    }

    /**
     * @notice repurchase using RA
     * @param id the id of PSM
     * @param amount the amount of RA to use
     */
    function repurchase(Id id, uint256 amount)
        external
        override
        nonReentrant
        PSMRepurchaseNotPaused(id)
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        )
    {
        State storage state = states[id];

        (dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates) =
            state.repurchase(_msgSender(), amount, getRouterCore(), getAmmRouter());

        emit Repurchased(id, _msgSender(), dsId, amount, receivedPa, receivedDs, feePercentage, fee, exchangeRates);
    }

    /**
     * @notice return the amount of available PA and DS to purchase.
     * @param id the id of PSM
     * @return pa the amount of PA available
     * @return ds the amount of DS available
     * @return dsId the id of the DS available
     */
    function availableForRepurchase(Id id) external view override returns (uint256 pa, uint256 ds, uint256 dsId) {
        State storage state = states[id];
        (pa, ds, dsId) = state.availableForRepurchase();
    }

    /**
     * @notice returns the repurchase rates for a given DS
     * @param id the id of PSM
     */
    function repurchaseRates(Id id) external view returns (uint256 rates) {
        State storage state = states[id];
        rates = state.repurchaseRates();
    }

    /**
     * @notice returns the amount of CT and DS tokens that will be received after deposit
     * @param id the id of PSM
     * @param amount the amount to be deposit
     * @return received the amount of CT/DS received
     * @return _exchangeRate effective exchange rate at time of deposit
     */
    function depositPsm(Id id, uint256 amount)
        external
        override
        onlyInitialized(id)
        PSMDepositNotPaused(id)
        returns (uint256 received, uint256 _exchangeRate)
    {
        State storage state = states[id];
        uint256 dsId;
        (dsId, received, _exchangeRate) = state.deposit(_msgSender(), amount);
        emit PsmDeposited(id, dsId, _msgSender(), amount, received, _exchangeRate);
    }

    function redeemRaWithDs(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes memory rawDsPermitSig,
        uint256 deadline
    )
        external
        override
        nonReentrant
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
        returns (uint256 received, uint256 _exchangeRate, uint256 fee)
    {
        State storage state = states[id];

        (received, _exchangeRate, fee) = state.redeemWithDs(redeemer, amount, dsId, rawDsPermitSig, deadline);

        VaultLibrary.provideLiquidityWithFee(state, fee, getRouterCore(), getAmmRouter());

        emit DsRedeemed(
            id, dsId, redeemer, amount, received, _exchangeRate, state.psm.psmBaseRedemptionFeePercentage, fee
        );
    }

    /**
     * This determines the rate of how much the user will receive for the amount of asset they want to deposit.
     * for example, if the rate is 1.5, then the user will need to deposit 1.5 token to get 1 CT and DS.
     * @param id the id of the PSM
     */
    function exchangeRate(Id id) external view override returns (uint256 rates) {
        State storage state = states[id];
        rates = state.exchangeRate();
    }

    function redeemWithCT(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes memory rawCtPermitSig,
        uint256 deadline
    )
        external
        override
        nonReentrant
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        State storage state = states[id];

        (accruedPa, accruedRa) = state.redeemWithCt(redeemer, amount, dsId, rawCtPermitSig, deadline);

        emit CtRedeemed(id, dsId, redeemer, amount, accruedPa, accruedRa);
    }

    /**
     * @notice returns amount of value locked in LV
     * @param id The PSM id
     */
    function valueLocked(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.valueLocked();
    }

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @param rawDsPermitSig raw signature for DS approval permit
     * @param dsDeadline deadline for DS approval permit signature
     * @param rawCtPermitSig raw signature for CT approval permit
     * @param ctDeadline deadline for CT approval permit signature
     */
    function redeemRaWithCtDs(
        Id id,
        uint256 amount,
        address redeemer,
        bytes memory rawDsPermitSig,
        uint256 dsDeadline,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external override nonReentrant PSMWithdrawalNotPaused(id) returns (uint256 ra) {
        State storage state = states[id];
        ra = state.redeemRaWithCtDs(redeemer, amount, rawDsPermitSig, dsDeadline, rawCtPermitSig, ctDeadline);

        emit Cancelled(id, state.globalAssetIdx, redeemer, ra, amount);
    }

    /**
     * @notice returns base redemption fees (1e18 = 1%)
     */
    function baseRedemptionFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.psm.psmBaseRedemptionFeePercentage;
    }

    function psmAcceptFlashSwapProfit(Id id, uint256 profit) external onlyFlashSwapRouter {
        State storage state = states[id];
        state.acceptRolloverProfit(profit);
    }

    function rolloverCt(
        Id id,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    )
        external
        PSMDepositNotPaused(id)
        returns (uint256 ctReceived, uint256 dsReceived, uint256 _exchangeRate, uint256 paReceived)
    {
        State storage state = states[id];
        (ctReceived, dsReceived, _exchangeRate, paReceived) =
            state.rolloverCt(owner, amount, dsId, getRouterCore(), rawCtPermitSig, ctDeadline);
        emit RolledOver(
            id, state.globalAssetIdx, owner, dsId, amount, dsReceived, ctReceived, paReceived, _exchangeRate
        );
    }

    function claimAutoSellProfit(Id id, uint256 dsId, uint256 amount)
        external
        nonReentrant
        returns (uint256 profit, uint256 dsReceived)
    {
        State storage state = states[id];
        (profit, dsReceived) = state.claimAutoSellProfit(getRouterCore(), _msgSender(), dsId, amount);
        emit RolloverProfitClaimed(id, dsId, _msgSender(), amount, profit, dsReceived);
    }

    function rolloverProfitRemaining(Id id, uint256 dsId) external view returns (uint256) {
        State storage state = states[id];
        return state.psm.poolArchive[dsId].rolloverClaims[msg.sender];
    }

    function updatePsmAutoSellStatus(Id id, address user, bool status) external {
        State storage state = states[id];
        state.updateAutoSell(user, status);
    }

    function psmAutoSellStatus(Id id) external view returns (bool) {
        State storage state = states[id];
        state.autoSellStatus(_msgSender());
    }
}
