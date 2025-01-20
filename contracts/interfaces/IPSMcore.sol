// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IRepurchase} from "./IRepurchase.sol";

/**
 * @title IPSMcore Interface
 * @author Cork Team
 * @notice IPSMcore interface for PSMCore contract
 */
interface IPSMcore is IRepurchase {
    /// @notice Emitted when the exchange rate is updated
    /// @param id The PSM id
    /// @param newRate The new rate
    /// @param previousRate The previous rate
    event RateUpdated(Id indexed id, uint256 newRate, uint256 previousRate);

    /// @notice Emitted when a user deposits assets into a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param depositor The address of the depositor
    /// @param amount The amount of the asset deposited
    /// @param received The amount of swap asset received
    /// @param exchangeRate The exchange rate of DS at the time of deposit
    event PsmDeposited(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed depositor,
        uint256 amount,
        uint256 received,
        uint256 exchangeRate
    );

    /// @notice Emitted when a user rolled over their CT
    /// @param Id The PSM id
    /// @param currentDsId The current DS id
    /// @param owner The address of the owner
    /// @param prevDsId The previous DS id
    /// @param amountCtRolledOver The amount of CT rolled over
    /// @param dsReceived The amount of DS received, if 0 then the DS is sold to flash swap router, and implies the user opt-in for DS auto-sell
    /// @param ctReceived The amount of CT received
    /// @param paReceived The amount of PA received
    event RolledOver(
        Id indexed Id,
        uint256 indexed currentDsId,
        address indexed owner,
        uint256 prevDsId,
        uint256 amountCtRolledOver,
        uint256 dsReceived,
        uint256 ctReceived,
        uint256 paReceived
    );

    /// @notice Emitted when a user claims profit from a rollover
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param owner The address of the owner
    /// @param amount The amount of the asset claimed
    /// @param profit The amount of profit claimed
    /// @param remainingDs The amount of DS remaining user claimed
    event RolloverProfitClaimed(
        Id indexed Id, uint256 indexed dsId, address indexed owner, uint256 amount, uint256 profit, uint256 remainingDs
    );

    /// @notice Emitted when a user redeems a DS for a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param paUsed The amount of the PA redeemed
    /// @param dsUsed The amount of DS redeemed
    /// @param raReceived The amount of  asset received
    /// @param dsExchangeRate The exchange rate of DS at the time of redeem
    /// @param feePercentage The fee percentage charged for redemption
    /// @param fee The fee charged for redemption
    event DsRedeemed(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 paUsed,
        uint256 dsUsed,
        uint256 raReceived,
        uint256 dsExchangeRate,
        uint256 feePercentage,
        uint256 fee
    );

    /// @notice Emitted when a user redeems a CT for a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the CT redeemed
    /// @param paReceived The amount of the pegged asset received
    /// @param raReceived The amount of the redemption asset received
    event CtRedeemed(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 amount,
        uint256 paReceived,
        uint256 raReceived
    );

    /// @notice Emitted when a user cancels their DS position by depositing the CT + DS back into the PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param raAmount The amount of RA received
    /// @param swapAmount The amount of CT + DS swapped
    event Cancelled(
        Id indexed Id, uint256 indexed dsId, address indexed redeemer, uint256 raAmount, uint256 swapAmount
    );

    /// @notice Emitted when a Admin updates status of Deposit in the PSM 
    /// @param Id The PSM id
    /// @param isPSMDepositPaused The new value saying if Deposit allowed in PSM or not
    event PsmDepositsStatusUpdated(
        Id indexed Id,
        bool isPSMDepositPaused
    );

    /// @notice Emitted when a Admin updates status of Withdrawal in the PSM
    /// @param Id The PSM id
    /// @param isPSMWithdrawalPaused The new value saying if Withdrawal allowed in PSM or not
    event PsmWithdrawalsStatusUpdated(
        Id indexed Id,
        bool isPSMWithdrawalPaused
    );

    /// @notice Emitted when a Admin updates status of Repurchase in the PSM
    /// @param Id The PSM id
    /// @param isPSMRepurchasePaused The new value saying if Repurchase allowed in PSM or not
    event PsmRepurchasesStatusUpdated(
        Id indexed Id,
        bool isPSMRepurchasePaused
    );

    /// @notice Emitted when a Admin updates fee rates for early redemption
    /// @param Id The PSM id
    /// @param earlyRedemptionFeeRate The new value of early redemption fee rate
    event EarlyRedemptionFeeRateUpdated(Id indexed Id, uint256 earlyRedemptionFeeRate);

    /// @notice Emmitted when psmBaseRedemptionFeePercentage is updated
    /// @param id the PSM id
    /// @param psmBaseRedemptionFeePercentage the new psmBaseRedemptionFeePercentage
    event PsmBaseRedemptionFeePercentageUpdated(Id indexed id, uint256 indexed psmBaseRedemptionFeePercentage);

    /**
     * @notice returns the amount of CT and DS tokens that will be received after deposit
     * @param id the id of PSM
     * @param amount the amount to be deposit
     * @return received the amount of CT/DS received
     * @return exchangeRate effective exchange rate at time of deposit
     */
    function depositPsm(Id id, uint256 amount) external returns (uint256 received, uint256 exchangeRate);

    /**
     * This determines the rate of how much the user will receive for the amount of asset they want to deposit.
     * for example, if the rate is 1.5, then the user will need to deposit 1.5 token to get 1 CT and DS.
     * @param id the id of the PSM
     */
    function exchangeRate(Id id) external view returns (uint256 rates);

    /**
     * @notice redeem RA with DS + PA
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of PA to redeem
     * @param redeemer The address of the redeemer
     * @param rawDsPermitSig The raw signature for DS approval permit
     * @param deadline The deadline for DS approval permit signature
     */
    function redeemRaWithDsPa(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed);

    /**
     * @notice redeem RA with DS + PA
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of PA to redeem
     * @return received The amount of RA user will get
     * @return _exchangeRate The effective rate at the time of redemption
     * @return fee The fee charged for redemption
     */
    function redeemRaWithDsPa(Id id, uint256 dsId, uint256 amount)
        external
        returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed);
    /**
     * @notice redeem RA + PA with CT at expiry
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of CT to redeem
     * @param redeemer The address of the redeemer
     * @param rawCtPermitSig The raw signature for CT approval permit
     * @param deadline The deadline for CT approval permit signature
     */
    function redeemWithExpiredCt(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) external returns (uint256 accruedPa, uint256 accruedRa);

    /**
     * @notice redeem RA + PA with CT at expiry
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of CT to redeem
     */
    function redeemWithExpiredCt(Id id, uint256 dsId, uint256 amount)
        external
        returns (uint256 accruedPa, uint256 accruedRa);

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @param redeemer The address of the redeemer
     * @param rawDsPermitSig raw signature for DS approval permit
     * @param dsDeadline deadline for DS approval permit signature
     * @param rawCtPermitSig raw signature for CT approval permit
     * @param ctDeadline deadline for CT approval permit signature
     * @return ra amount of RA user received
     */
    function returnRaWithCtDs(
        Id id,
        uint256 amount,
        address redeemer,
        bytes memory rawDsPermitSig,
        uint256 dsDeadline,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ra);

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @return ra amount of RA user received
     */
    function returnRaWithCtDs(Id id, uint256 amount) external returns (uint256 ra);

    /**
     * @notice returns amount of value locked in LV
     * @param id The PSM id
     */
    function valueLocked(Id id) external view returns (uint256);

    /**
     * @notice returns base redemption fees (1e18 = 1%)
     */
    function baseRedemptionFee(Id id) external view returns (uint256);

    function psmAcceptFlashSwapProfit(Id id, uint256 profit) external;

    function rolloverExpiredCt(
        Id id,
        address owner,
        uint256 amount,
        uint256 prevDsId,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived);

    function claimAutoSellProfit(Id id, uint256 prevDsId, uint256 amount)
        external
        returns (uint256 profit, uint256 dsReceived);

    function rolloverExpiredCt(Id id, uint256 amount, uint256 prevDsId)
        external
        returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived);

    function updatePsmAutoSellStatus(Id id, bool status) external;

    function rolloverProfitRemaining(Id id, uint256 dsId) external view returns (uint256);

    function psmAutoSellStatus(Id id) external view returns (bool);

    function updateRate(Id id, uint256 newRate) external;
}
