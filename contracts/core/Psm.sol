pragma solidity 0.8.24;

import {PsmLibrary} from "../libraries/PsmLib.sol";
import {VaultLibrary} from "../libraries/VaultLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {IPSMcore} from "../interfaces/IPSMcore.sol";
import {State} from "../libraries/State.sol";
import {ModuleState} from "./ModuleState.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title PsmCore Abstract Contract
 * @author Cork Team
 * @notice Abstract PsmCore contract provides PSM related logics
 */
abstract contract PsmCore is IPSMcore, ModuleState, Context {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    /**
     * @notice returns the fee precentage for repurchasing(1e18 = 1%)
     * @param id the id of PSM
     */
    function repurchaseFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.repurchaseFeePrecentage();
    }

    /**
     * @notice repurchase using RA
     * @param id the id of PSM
     * @param amount the amount of RA to use
     */
    function repurchase(Id id, uint256 amount) external override {
        State storage state = states[id];
        (uint256 dsId, uint256 received, uint256 feePrecentage, uint256 fee, uint256 exchangeRates) =
            state.repurchase(_msgSender(), amount, getRouterCore(), getAmmRouter());

        emit Repurchased(id, _msgSender(), dsId, amount, received, feePrecentage, fee, exchangeRates);
    }

    /**
     * @notice returns the amount of pa and ds tokens that will be received after repurchasing
     * @param id the id of PSM
     * @param amount the amount of RA to use
     * @return dsId the id of the DS
     * @return received the amount of RA received
     * @return feePrecentage the fee in precentage
     * @return fee the fee charged
     * @return exchangeRates the effective DS exchange rate at the time of repurchase
     */
    function previewRepurchase(Id id, uint256 amount)
        external
        view
        override
        returns (uint256 dsId, uint256 received, uint256 feePrecentage, uint256 fee, uint256 exchangeRates)
    {
        State storage state = states[id];
        (dsId, received, feePrecentage, fee, exchangeRates,) = state.previewRepurchase(amount);
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

    function previewDepositPsm(Id id, uint256 amount)
        external
        view
        override
        onlyInitialized(id)
        PSMDepositNotPaused(id)
        returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId)
    {
        State storage state = states[id];
        (ctReceived, dsReceived, dsId) = state.previewDeposit(amount);
    }

    function redeemRaWithDs(Id id, uint256 dsId, uint256 amount, bytes memory rawDsPermitSig, uint256 deadline)
        external
        override
        nonReentrant
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        // gas savings
        uint256 feePrecentage = psmBaseRedemptionFeePrecentage;

        (uint256 received, uint256 _exchangeRate, uint256 fee) =
            state.redeemWithDs(_msgSender(), amount, dsId, rawDsPermitSig, deadline, feePrecentage);

        VaultLibrary.provideLiquidityWithFee(state, fee, getRouterCore(), getAmmRouter());

        emit DsRedeemed(id, dsId, _msgSender(), amount, received, _exchangeRate, feePrecentage, fee);
    }

    function redeemRaWithDs(Id id, uint256 dsId, uint256 amount)
        external
        override
        nonReentrant
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
    {
        State storage state = states[id];
        // gas savings
        uint256 feePrecentage = psmBaseRedemptionFeePrecentage;

        (uint256 received, uint256 _exchangeRate, uint256 fee) =
            state.redeemWithDs(_msgSender(), amount, dsId, bytes(""), 0, feePrecentage);

        VaultLibrary.provideLiquidityWithFee(state, fee, getRouterCore(), getAmmRouter());

        emit DsRedeemed(id, dsId, _msgSender(), amount, received, _exchangeRate, feePrecentage, fee);
    }

    function exchangeRate(Id id) external view override returns (uint256 rates) {
        State storage state = states[id];
        rates = state.exchangeRate();
    }

    function previewRedeemRaWithDs(Id id, uint256 dsId, uint256 amount)
        external
        view
        override
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
        returns (uint256 assets)
    {
        State storage state = states[id];
        assets = state.previewRedeemWithDs(dsId, amount);
    }

    function redeemWithCT(Id id, uint256 dsId, uint256 amount, bytes memory rawCtPermitSig, uint256 deadline)
        external
        override
        nonReentrant
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
    {
        State storage state = states[id];

        (uint256 accruedPa, uint256 accruedRa) =
            state.redeemWithCt(_msgSender(), amount, dsId, rawCtPermitSig, deadline);

        emit CtRedeemed(id, dsId, _msgSender(), amount, accruedPa, accruedRa);
    }

    function redeemWithCT(Id id, uint256 dsId, uint256 amount)
        external
        override
        nonReentrant
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
    {
        State storage state = states[id];

        (uint256 accruedPa, uint256 accruedRa) = state.redeemWithCt(_msgSender(), amount, dsId, bytes(""), 0);

        emit CtRedeemed(id, dsId, _msgSender(), amount, accruedPa, accruedRa);
    }

    function previewRedeemWithCt(Id id, uint256 dsId, uint256 amount)
        external
        view
        override
        onlyInitialized(id)
        PSMWithdrawalNotPaused(id)
        returns (uint256 paReceived, uint256 raReceived)
    {
        State storage state = states[id];
        (paReceived, raReceived) = state.previewRedeemWithCt(dsId, amount);
    }

    function valueLocked(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.valueLocked();
    }

    function redeemRaWithCtDs(
        Id id,
        uint256 amount,
        bytes memory rawDsPermitSig,
        uint256 dsDeadline,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external override nonReentrant PSMWithdrawalNotPaused(id) {
        State storage state = states[id];
        (uint256 ra, uint256 dsId, uint256 rates) =
            state.redeemRaWithCtDs(_msgSender(), amount, rawDsPermitSig, dsDeadline, rawCtPermitSig, ctDeadline);

        emit Cancelled(id, dsId, _msgSender(), ra, amount, rates);
    }

    function redeemRaWithCtDs(Id id, uint256 amount)
        external
        override
        nonReentrant
        PSMWithdrawalNotPaused(id)
        returns (uint256 received, uint256 rates)
    {
        State storage state = states[id];
        uint256 dsId;

        (received, dsId, rates) = state.redeemRaWithCtDs(_msgSender(), amount, bytes(""), 0, bytes(""), 0);

        emit Cancelled(id, dsId, _msgSender(), received, amount, rates);
    }

    function previewRedeemRaWithCtDs(Id id, uint256 amount)
        external
        view
        override
        PSMWithdrawalNotPaused(id)
        returns (uint256 ra, uint256 rates)
    {
        State storage state = states[id];
        (ra,, rates) = state.previewRedeemRaWithCtDs(amount);
    }

    function baseRedemptionFee() external view override returns (uint256) {
        return psmBaseRedemptionFeePrecentage;
    }
}
