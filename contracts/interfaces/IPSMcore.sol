pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IRepurchase} from "./IRepurchase.sol";

/**
 * @title IPSMcore Interface
 * @author Cork Team
 * @notice IPSMcore interface for PSMCore contract
 */
interface IPSMcore is IRepurchase {
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
    /// @param exchangeRate The exchange rate of DS at the time of rollover
    event RolledOver(
        Id indexed Id,
        uint256 indexed currentDsId,
        address indexed owner,
        uint256 prevDsId,
        uint256 amountCtRolledOver,
        uint256 dsReceived,
        uint256 ctReceived,
        uint256 paReceived,
        uint256 exchangeRate
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
    /// @param amount The amount of the DS redeemed
    /// @param received The amount of  asset received
    /// @param dsExchangeRate The exchange rate of DS at the time of redeem
    /// @param feePercentage The fee percentage charged for redemption
    /// @param fee The fee charged for redemption
    event DsRedeemed(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 amount,
        uint256 received,
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
    /// @param dSexchangeRates The exchange rate between RA:(CT+DS) at the time of the swap
    event Cancelled(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 raAmount,
        uint256 swapAmount,
        uint256 dSexchangeRates
    );

    /// @notice Emitted when a Admin updates status of Deposit/Withdraw in the PSM / LV
    /// @param Id The PSM id
    /// @param isPSMDepositPaused The new value saying if Deposit allowed in PSM or not
    /// @param isPSMWithdrawalPaused The new value saying if Withdrawal allowed in PSM or not
    /// @param isPSMRepurchasePaused The new value saying if Repurcahse allowed in PSM or not
    /// @param isLVDepositPaused The new value saying if Deposit allowed in LV or not
    /// @param isLVWithdrawalPaused The new value saying if Withdrawal allowed in LV or not
    event PoolsStatusUpdated(
        Id indexed Id,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isPSMRepurchasePaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
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
     * @notice returns the amount of CT and DS tokens that will be received after deposit
     * @param id the id of PSM
     * @param amount the amount to be deposit
     * @return ctReceived the amount of CT will be received
     * @return dsReceived the amount of DS will be received
     * @return dsId Id of DS
     */
    function previewDepositPsm(Id id, uint256 amount)
        external
        view
        returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId);

    /**
     * @notice redeem RA with DS + PA
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of DS + PA to redeem
     * @param redeemer The address of the redeemer
     * @param rawDsPermitSig The raw signature for DS approval permit
     * @param deadline The deadline for DS approval permit signature
     */
    function redeemRaWithDs(Id id, uint256 dsId, uint256 amount, address redeemer, bytes memory rawDsPermitSig, uint256 deadline)
        external
        returns (uint256 received, uint256 _exchangeRate, uint256 fee);

    /**
     * @notice redeem RA with DS + PA
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of DS + PA to redeem
     */
    function redeemRaWithDs(Id id, uint256 dsId, uint256 amount)
        external
        returns (uint256 received, uint256 _exchangeRate, uint256 fee);

    /**
     * @notice preview the amount of RA user will get when Redeem RA with DS+PA
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of DS + PA to redeem
     */
    function previewRedeemRaWithDs(Id id, uint256 dsId, uint256 amount)
        external
        view
        returns (uint256 assets, uint256 fee, uint256 feePercentage);

    /**
     * @notice redeem RA + PA with CT at expiry
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of CT to redeem
     * @param redeemer The address of the redeemer
     * @param rawCtPermitSig The raw signature for CT approval permit
     * @param deadline The deadline for CT approval permit signature
     */
    function redeemWithCT(Id id, uint256 dsId, uint256 amount, address redeemer, bytes memory rawCtPermitSig, uint256 deadline)
        external
        returns (uint256 accruedPa, uint256 accruedRa);

    /**
     * @notice redeem RA + PA with CT at expiry
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of CT to redeem
     */
    function redeemWithCT(Id id, uint256 dsId, uint256 amount)
        external
        returns (uint256 accruedPa, uint256 accruedRa);

    /**
     * @notice preview the amount of RA user will get when Redeem RA with CT+DS
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of CT to redeem
     * @return paReceived The amount of PA user will get
     * @return raReceived The amount of RA user will get
     */
    function previewRedeemWithCt(Id id, uint256 dsId, uint256 amount)
        external
        view
        returns (uint256 paReceived, uint256 raReceived);

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
     * @return dsId the id of DS
     * @return rates the effective rate at the time of redemption
     */
    function redeemRaWithCtDs(
        Id id,
        uint256 amount,
        address redeemer,
        bytes memory rawDsPermitSig,
        uint256 dsDeadline,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ra, uint256 dsId, uint256 rates);

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @return ra amount of RA user received
     * @return dsId the id of DS
     * @return rates the effective rate at the time of redemption
     */
    function redeemRaWithCtDs(Id id, uint256 amount) external returns (uint256 ra, uint256 dsId, uint256 rates);

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @return ra amount of RA user will get
     * @return rates the effective rate at the time of redemption
     */
    function previewRedeemRaWithCtDs(Id id, uint256 amount) external view returns (uint256 ra, uint256 rates);

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

    function rolloverCt(
        Id id,
        address owner,
        uint256 amount,
        uint256 prevDsId,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ctReceived, uint256 dsReceived, uint256 _exchangeRate, uint256 paReceived);

    function rolloverCt(Id id, address owner, uint256 amount, uint256 prevDsId)
        external
        returns (uint256 ctReceived, uint256 dsReceived, uint256 _exchangeRate, uint256 paReceived);

    function claimAutoSellProfit(Id id, uint256 prevDsId, uint256 amount)
        external
        returns (uint256 profit, uint256 dsReceived);

    function updatePsmAutoSellStatus(Id id, address user, bool status) external;

    function rolloverProfitRemaining(Id id, uint256 dsId) external view returns (uint256);
}
