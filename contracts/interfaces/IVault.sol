// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {IWithdrawal} from "./IWithdrawal.sol";
import {IErrors} from "./IErrors.sol";

/**
 * @title Vault Interface
 * @author Cork Team
 * @notice Interface for the main Vault contract that handles deposits and early redemptions
 */
interface IVault is IErrors {
    struct ProtocolContracts {
        IDsFlashSwapCore flashSwapRouter;
        ICorkHook ammRouter;
        IWithdrawal withdrawalContract;
    }

    struct PermitParams {
        bytes rawLvPermitSig;
        uint256 deadline;
    }

    struct RedeemEarlyParams {
        Id id;
        uint256 amount;
        uint256 amountOutMin;
        uint256 ammDeadline;
        uint256 ctAmountOutMin;
        uint256 dsAmountOutMin;
        uint256 paAmountOutMin;
    }

    struct RedeemEarlyResult {
        Id id;
        address receiver;
        uint256 raReceivedFromAmm;
        uint256 raIdleReceived;
        uint256 paReceived;
        uint256 ctReceivedFromAmm;
        uint256 ctReceivedFromVault;
        uint256 dsReceived;
        bytes32 withdrawalId;
    }

    /// @notice Emitted when you deposit assets into the Vault
    /// @param id Which vault you deposited into
    /// @param depositor Your address
    /// @param received How many vault tokens you received
    /// @param deposited How much you deposited
    event LvDeposited(Id indexed id, address indexed depositor, uint256 received, uint256 deposited);

    /// @notice Emitted when you redeem your vault tokens early
    /// @param id Which vault you redeemed from
    /// @param redeemer Who initiated the redemption
    /// @param receiver Who received the assets
    /// @param lvBurned How many vault tokens were burned
    /// @param ctReceivedFromAmm How many CT tokens you got from the trading pool
    /// @param ctReceivedFromVault How many CT tokens you got directly from the vault
    /// @param dsReceived How many DS tokens you received
    /// @param paReceived How much pegged asset you received
    /// @param raReceivedFromAmm How much redemption asset you got from the trading pool
    /// @param raIdleReceived How much redemption asset you got directly from the vault
    /// @param withdrawalId Your withdrawal request ID
    event LvRedeemEarly(
        Id indexed id,
        address indexed redeemer,
        address indexed receiver,
        uint256 lvBurned,
        uint256 ctReceivedFromAmm,
        uint256 ctReceivedFromVault,
        uint256 dsReceived,
        uint256 paReceived,
        uint256 raReceivedFromAmm,
        uint256 raIdleReceived,
        bytes32 withdrawalId
    );

    /// @notice Emitted when the vault's value reference is updated
    /// @param snapshotIndex Which snapshot was updated (0 or 1)
    /// @param newValue The new value of the snapshot
    event SnapshotUpdated(uint256 snapshotIndex, uint256 newValue);

    /// @notice Emitted when deposits are paused or unpaused
    /// @param id Which vault was affected
    /// @param isLVDepositPaused True if deposits are now paused, false if enabled
    event LvDepositsStatusUpdated(Id indexed id, bool isLVDepositPaused);

    /// @notice Emitted when withdrawals are paused or unpaused
    /// @param id Which vault was affected
    /// @param isLVWithdrawalPaused True if withdrawals are now paused, false if enabled
    event LvWithdrawalsStatusUpdated(Id indexed id, bool isLVWithdrawalPaused);

    /// @notice Emitted when the protocol receives profit from trading
    /// @param router The router that sent the profit
    /// @param amount How much profit was received
    event ProfitReceived(address indexed router, uint256 amount);

    /// @notice Emitted when the vault's safety threshold is updated
    /// @param id Which vault was updated
    /// @param navThreshold The new threshold value
    event VaultNavThresholdUpdated(Id indexed id, uint256 navThreshold);

    /**
     * @notice Deposit your assets into the vault
     * @param id Which vault you want to deposit into
     * @param amount How much you want to deposit
     * @param raTolerance Your acceptable price slippage for redemption assets
     * @param ctTolerance Your acceptable price slippage for CT tokens
     * @return received How many vault tokens you'll get
     */
    function depositLv(Id id, uint256 amount, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received);

    /**
     * @notice Redeem your vault tokens before expiry (with permit)
     * @param redeemParams Details about your redemption (amount, minimum outputs, etc.)
     * @param permitParams Your permission signature to use the vault tokens
     * @return result Details about what you received from the redemption
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams, PermitParams memory permitParams)
        external
        returns (RedeemEarlyResult memory result);

    /**
     * @notice Redeem your vault tokens before expiry
     * @param redeemParams Details about your redemption (amount, minimum outputs, etc.)
     * @return result Details about what you received from the redemption
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams) external returns (RedeemEarlyResult memory result);

    /**
     * @notice Add liquidity to the trading pool using fees from DS sales
     * @param id Which vault to add liquidity for
     * @param amount How much to add
     */
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external;

    /**
     * @notice Check how many trading pool tokens the vault holds
     * @param id Which vault to check
     * @return The amount of LP tokens held
     */
    function vaultLp(Id id) external view returns (uint256);

    /**
     * @notice Accept profit from rollover operations
     * @param id Which vault receives the profit
     * @param amount How much profit to accept
     */
    function lvAcceptRolloverProfit(Id id, uint256 amount) external;

    /**
     * @notice Update the percentage of CT tokens held by the vault
     * @param id Which vault to update
     * @param ctHeldPercentage The new percentage to hold
     */
    function updateCtHeldPercentage(Id id, uint256 ctHeldPercentage) external;

    /**
     * @notice Get the address of the vault token
     * @param id Which vault to check
     * @return lv The address of the vault token
     */
    function lvAsset(Id id) external view returns (address lv);

    /**
     * @notice Get the total redemption assets in the vault at a specific time
     * @param id Which vault to check
     * @param dsId Which DS series to check
     * @return The total amount of redemption assets
     */
    function totalRaAt(Id id, uint256 dsId) external view returns (uint256);

    /**
     * @notice Update the safety threshold for the vault
     * @param id Which vault to update
     * @param newNavThreshold The new threshold value
     */
    function updateVaultNavThreshold(Id id, uint256 newNavThreshold) external;
}
