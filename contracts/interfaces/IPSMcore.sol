// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/Pair.sol";
import "./IRepurchase.sol";

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

    /// @notice Emitted when a user redeems a DS for a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the DS redeemed
    /// @param received The amount of  asset received
    /// @param dsExchangeRate The exchange rate of DS at the time of redeem
    event DsRedeemed(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 amount,
        uint256 received,
        uint256 dsExchangeRate
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
    /// @param isLVDepositPaused The new value saying if Deposit allowed in LV or not
    /// @param isLVWithdrawalPaused The new value saying if Withdrawal allowed in LV or not
    event PoolsStatusUpdated(
        Id indexed Id,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    );

    function depositPsm(
        Id id,
        uint256 amount
    ) external returns (uint256 received, uint256 exchangeRate);

    /**
     * This determines the rate of how much the user will receive for the amount of asset they want to deposit.
     * for example, if the rate is 1.5, then the user will need to deposit 1.5 token to get 1 CT and DS.
     * @param id the id of the PSM
     */
    function exchangeRate(Id id) external view returns (uint256 rates);

    function previewDepositPsm(
        Id id,
        uint256 amount
    )
        external
        view
        returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId);

    function redeemRaWithDs(
        Id id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external;

    function previewRedeemRaWithDs(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 assets);

    function redeemWithCT(
        Id id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) external;

    function previewRedeemWithCt(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 paReceived, uint256 raReceived);

    function redeemRaWithCtDs(
        Id id,
        uint256 amount
    ) external returns (uint256 ra, uint256 rates);

    function previewRedeemRaWithCtDs(
        Id id,
        uint256 amount
    ) external view returns (uint256 ra, uint256 rates);

    function valueLocked(Id id) external view returns (uint256);
}
