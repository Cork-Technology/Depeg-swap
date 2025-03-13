// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PsmLibrary} from "../libraries/PsmLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {IPSMcore} from "../interfaces/IPSMcore.sol";
import {State} from "../libraries/State.sol";
import {ModuleState} from "./ModuleState.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IExchangeRateProvider} from "./../interfaces/IExchangeRateProvider.sol";

/**
 * @title PsmCore Abstract Contract
 * @author Cork Team
 * @notice Abstract PsmCore contract provides PSM related logics
 */
abstract contract PsmCore is IPSMcore, ModuleState, Context {
    using PsmLibrary for State;
    using PairLibrary for Pair;

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
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        )
    {
        PSMRepurchaseNotPaused(id);

        State storage state = states[id];

        (dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates) =
            state.repurchase(_msgSender(), amount, getTreasuryAddress());

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
    function depositPsm(Id id, uint256 amount) external override returns (uint256 received, uint256 _exchangeRate) {
        onlyInitialized(id);
        PSMDepositNotPaused(id);

        State storage state = states[id];
        uint256 dsId;
        (dsId, received, _exchangeRate) = state.deposit(_msgSender(), amount);
        emit PsmDeposited(id, dsId, _msgSender(), amount, received, _exchangeRate);
    }

    /**
     * @notice Redeems RA tokens for DS tokens using the PSM (Peg Stability Module).
     * @dev This function allows a user to redeem RA tokens for DS tokens, subject to certain conditions and fees.
     * @param id The identifier for the PSM instance.
     * @param dsId The identifier for the DS token.
     * @param amount The amount of RA tokens to redeem.
     * @param redeemer The address of the user redeeming the tokens.
     * @param rawDsPermitSig The raw signature for the DS permit.
     * @param deadline The deadline for the permit signature.
     * @return received The amount of DS tokens received.
     * @return _exchangeRate The exchange rate used for the redemption.
     * @return fee The fee charged for the redemption.
     * @return dsUsed The amount of DS tokens used in the redemption.
     */
    function redeemRaWithDsPa(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes calldata rawDsPermitSig,
        uint256 deadline
    ) external override nonReentrant returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed) {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        if (rawDsPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];

        (received, _exchangeRate, fee, dsUsed) =
            state.redeemWithDs(redeemer, amount, dsId, rawDsPermitSig, deadline, getTreasuryAddress());

        emit DsRedeemed(
            id, dsId, redeemer, amount, dsUsed, received, _exchangeRate, state.psm.psmBaseRedemptionFeePercentage, fee
        );
    }

    /**
     * @notice Redeems RA (Reserve Asset) with DS (Depeg Stablecoin) for a given ID.
     * @dev This function allows users to redeem their Reserve Assets using Depeg Stablecoins.
     * It ensures the contract is initialized and the withdrawal is not paused.
     * @param id The identifier for the specific reserve asset.
     * @param dsId The identifier for the specific depeg stablecoin.
     * @param amount The amount of reserve asset to redeem.
     * @return received The amount of depeg stablecoin received.
     * @return _exchangeRate The exchange rate applied during the redemption.
     * @return fee The fee charged for the redemption.
     * @return dsUsed The amount of depeg stablecoin used in the redemption.
     */
    function redeemRaWithDsPa(Id id, uint256 dsId, uint256 amount)
        external
        override
        nonReentrant
        returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed)
    {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        State storage state = states[id];

        (received, _exchangeRate, fee, dsUsed) =
            state.redeemWithDs(_msgSender(), amount, dsId, bytes(""), 0, getTreasuryAddress());

        emit DsRedeemed(
            id,
            dsId,
            _msgSender(),
            amount,
            dsUsed,
            received,
            _exchangeRate,
            state.psm.psmBaseRedemptionFeePercentage,
            fee
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

    /**
     * @notice Redeems an expired certificate token (Ct) for the specified amount.
     * @dev This function allows the redeemer to redeem an expired certificate token.
     *      It requires a valid permit signature and a deadline.
     * @param id The identifier of the certificate token.
     * @param dsId The identifier of the data source.
     * @param amount The amount of the certificate token to redeem.
     * @param redeemer The address of the redeemer.
     * @param rawCtPermitSig The raw permit signature for the certificate token.
     * @param deadline The deadline for the permit signature.
     * @return accruedPa The accrued principal amount.
     * @return accruedRa The accrued reward amount.
     */
    function redeemWithExpiredCt(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes calldata rawCtPermitSig,
        uint256 deadline
    ) external override nonReentrant returns (uint256 accruedPa, uint256 accruedRa) {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        if (rawCtPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];

        (accruedPa, accruedRa) = state.redeemWithExpiredCt(redeemer, amount, dsId, rawCtPermitSig, deadline);

        emit CtRedeemed(id, dsId, redeemer, amount, accruedPa, accruedRa);
    }

    /**
     * @notice Redeems tokens with an expired certificate.
     * @dev This function allows the redemption of tokens using an expired certificate.
     * It ensures that the contract is initialized and that withdrawals are not paused.
     * The function is non-reentrant.
     * @param id The identifier of the certificate.
     * @param dsId The identifier of the data source.
     * @param amount The amount of tokens to redeem.
     * @return accruedPa The accrued primary amount.
     * @return accruedRa The accrued reserve amount.
     */
    function redeemWithExpiredCt(Id id, uint256 dsId, uint256 amount)
        external
        override
        nonReentrant
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        State storage state = states[id];

        (accruedPa, accruedRa) = state.redeemWithExpiredCt(_msgSender(), amount, dsId, bytes(""), 0);

        emit CtRedeemed(id, dsId, _msgSender(), amount, accruedPa, accruedRa);
    }

    /**
     * @notice returns amount of value locked in the PSM
     * @param id The PSM id
     */
    function valueLocked(Id id, bool ra) external view override returns (uint256) {
        State storage state = states[id];
        return state.valueLocked(ra);
    }

    function valueLocked(Id id, uint256 dsId, bool ra) external view override returns (uint256) {
        State storage state = states[id];
        return state.valueLocked(dsId, ra);
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
    function returnRaWithCtDs(
        Id id,
        uint256 amount,
        address redeemer,
        bytes calldata rawDsPermitSig,
        uint256 dsDeadline,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external override nonReentrant returns (uint256 ra) {
        PSMWithdrawalNotPaused(id);

        if (rawDsPermitSig.length == 0 || dsDeadline == 0 || rawCtPermitSig.length == 0 || ctDeadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];
        ra = state.returnRaWithCtDs(redeemer, amount, rawDsPermitSig, dsDeadline, rawCtPermitSig, ctDeadline);

        emit Cancelled(id, state.globalAssetIdx, redeemer, ra, amount);
    }

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @return ra amount of RA user received
     */
    function returnRaWithCtDs(Id id, uint256 amount) external override nonReentrant returns (uint256 ra) {
        PSMWithdrawalNotPaused(id);

        State storage state = states[id];

        ra = state.returnRaWithCtDs(_msgSender(), amount, bytes(""), 0, bytes(""), 0);

        emit Cancelled(id, state.globalAssetIdx, _msgSender(), ra, amount);
    }

    /**
     * @notice returns base redemption fees (1e18 = 1%)
     */
    function baseRedemptionFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.psm.psmBaseRedemptionFeePercentage;
    }

    /**
     * @notice Accepts the profit from a flash swap.
     * @dev This function can only be called by the flash swap router.
     * @param id The identifier of the state.
     * @param profit The amount of profit to accept.
     */
    function psmAcceptFlashSwapProfit(Id id, uint256 profit) external {
        onlyFlashSwapRouter();
        State storage state = states[id];
        state.acceptRolloverProfit(profit);
    }

    /**
     * @notice Rolls over an expired collateral token (CT) to a new deposit.
     * @dev This function requires a valid permit signature and deadline for the CT.
     * @param id The identifier of the deposit.
     * @param owner The address of the owner of the deposit.
     * @param amount The amount of the deposit to rollover.
     * @param dsId The identifier of the new deposit.
     * @param rawCtPermitSig The raw permit signature for the CT.
     * @param ctDeadline The deadline for the CT permit.
     * @return ctReceived The amount of CT received.
     * @return dsReceived The amount of DS received.
     * @return paReceived The amount of PA received.
     */
    function rolloverExpiredCt(
        Id id,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived) {
        PSMDepositNotPaused(id);
        if (rawCtPermitSig.length == 0 || ctDeadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];
        (ctReceived, dsReceived, paReceived) =
            state.rolloverExpiredCt(owner, amount, dsId, getRouterCore(), rawCtPermitSig, ctDeadline);
        emit RolledOver(id, state.globalAssetIdx, owner, dsId, amount, dsReceived, ctReceived, paReceived);
    }

    /**
     * @notice Rolls over expired collateral tokens (CT) to new tokens.
     * @dev This function allows users to rollover their expired collateral tokens to new tokens.
     * @param id The identifier of the collateral token.
     * @param amount The amount of expired collateral tokens to rollover.
     * @param dsId The identifier of the destination token.
     * @return ctReceived The amount of new collateral tokens received.
     * @return dsReceived The amount of destination tokens received.
     * @return paReceived The amount of additional tokens received.
     */
    function rolloverExpiredCt(Id id, uint256 amount, uint256 dsId)
        external
        returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived)
    {
        PSMDepositNotPaused(id);
        State storage state = states[id];
        // slither-disable-next-line uninitialized-local
        bytes memory signaturePlaceHolder;
        (ctReceived, dsReceived, paReceived) =
            state.rolloverExpiredCt(_msgSender(), amount, dsId, getRouterCore(), signaturePlaceHolder, 0);
        emit RolledOver(id, state.globalAssetIdx, _msgSender(), dsId, amount, dsReceived, ctReceived, paReceived);
    }

    /**
     * @notice Claims the profit from auto-selling a specific amount of tokens.
     * @dev This function is non-reentrant.
     * @param id The identifier of the state.
     * @param dsId The identifier of the ds.
     * @param amount The amount of tokens to auto-sell.
     * @return profit The profit obtained from the auto-sell.
     * @return dsReceived The amount of ds received from the auto-sell.
     */
    function claimAutoSellProfit(Id id, uint256 dsId, uint256 amount)
        external
        nonReentrant
        returns (uint256 profit, uint256 dsReceived)
    {
        State storage state = states[id];
        (profit, dsReceived) = state.claimAutoSellProfit(getRouterCore(), _msgSender(), dsId, amount);
        emit RolloverProfitClaimed(id, dsId, _msgSender(), amount, profit, dsReceived);
    }

    /**
     * @notice Returns the rollover profit remaining for a given pool and user.
     * @param id The identifier of the state.
     * @param dsId The identifier of the pool archive.
     * @return The rollover profit remaining for the caller.
     */
    function rolloverProfitRemaining(Id id, uint256 dsId) external view returns (uint256) {
        State storage state = states[id];
        return state.psm.poolArchive[dsId].rolloverClaims[msg.sender];
    }
    /**
     * @notice Updates the auto-sell status for a given state.
     * @param id The identifier of the state.
     * @param status The new auto-sell status.
     */

    function updatePsmAutoSellStatus(Id id, bool status) external {
        State storage state = states[id];
        state.updateAutoSell(_msgSender(), status);
    }
    /**
     * @notice Returns the auto-sell status for a given state.
     * @param id The identifier of the state.
     * @return The auto-sell status for the caller.
     */

    function psmAutoSellStatus(Id id) external view returns (bool) {
        State storage state = states[id];
        return state.autoSellStatus(_msgSender());
    }

    /**
     * @notice Updates the base redemption fee treasury split percentage for a given state.
     * @param id The identifier of the state.
     * @param percentage The new base redemption fee treasury split percentage.
     */
    function updatePsmBaseRedemptionFeeTreasurySplitPercentage(Id id, uint256 percentage) external {
        onlyConfig();
        State storage state = states[id];
        state.psm.psmBaseFeeTreasurySplitPercentage = percentage;
    }
    /**
     * @notice Updates the repurchase fee treasury split percentage for a given state.
     * @param id The identifier of the state.
     * @param percentage The new repurchase fee treasury split percentage.
     */

    function updatePsmRepurchaseFeeTreasurySplitPercentage(Id id, uint256 percentage) external {
        onlyConfig();
        State storage state = states[id];
        state.psm.repurchaseFeeTreasurySplitPercentage = percentage;
    }
}
