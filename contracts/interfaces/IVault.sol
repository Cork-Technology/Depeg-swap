// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {IWithdrawal} from "./IWithdrawal.sol";
import {ICommon} from "./ICommon.sol";

/**
 * @title IVault Interface
 * @author Cork Team
 * @notice IVault interface for VaultCore contract
 */
interface IVault is ICommon {
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

    /// @notice Emitted when a user deposits assets into a given Vault
    /// @param id The Module id that is used to reference both psm and lv of a given pair
    /// @param depositor The address of the depositor
    /// @param amount  The amount of the asset deposited
    event LvDeposited(Id indexed id, address indexed depositor, uint256 amount);

    event LvRedeemEarly(
        Id indexed Id,
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

    /// @notice Emitted when a Admin updates status of Deposit in the LV 
    /// @param Id The LV id
    /// @param isLVDepositPaused The new value saying if Deposit allowed in LV or not
    event LvDepositsStatusUpdated(
        Id indexed Id,
        bool isLVDepositPaused
    );

    /// @notice Emitted when a Admin updates status of Withdrawal in the LV
    /// @param Id The LV id
    /// @param isLVWithdrawalPaused The new value saying if Withdrawal allowed in LV or not
    event LvWithdrawalsStatusUpdated(
        Id indexed Id,
        bool isLVWithdrawalPaused
    );

    /// @notice Emitted when the protocol receive sales profit from the router
    /// @param router The address of the router
    /// @param amount The amount of RA tokens transferred.
    event ProfitReceived(address indexed router, uint256 amount);

    /// @notice caller is not authorized to perform the action, e.g transfering
    /// redemption rights to another address while not having the rights
    error Unauthorized(address caller);

    /// @notice invalid parameters, e.g passing 0 as amount
    error InvalidParams();

    /// @notice inssuficient balance to perform expiry redeem(e.g requesting 5 LV to redeem but trying to redeem 10)
    error InsufficientBalance(address caller, uint256 requested, uint256 balance);

    /// @notice insufficient output amount, e.g trying to redeem 100 LV whcih you expect 100 RA but only received 50 RA
    error InsufficientOutputAmount(uint256 amountOutMin, uint256 received);

    /// @notice vault does not have sufficient funds to do something
    error InsufficientFunds();

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     */
    function depositLv(Id id, uint256 amount, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received);

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     * @param redeemer The address of the redeemer
     * @param permitParams The object with details for permit like rawLvPermitSig(Raw signature for LV approval permit) and deadline for signature
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams, address redeemer, PermitParams memory permitParams)
        external
        returns (RedeemEarlyResult memory result);

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams) external returns (RedeemEarlyResult memory result);

    /**
     * This will accure value for LV holders by providing liquidity to the AMM using the RA received from selling DS when a users buys DS
     * @param id the id of the pair
     * @param amount the amount of RA received from selling DS
     */
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external;

    /**
     * Returns the amount of AMM LP tokens that the vault holds
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function vaultLp(Id id) external view returns (uint256);

    function lvAcceptRolloverProfit(Id id, uint256 amount) external;

    function updateCtHeldPercentage(Id id, uint256 ctHeldPercentage) external;

    function lvAsset(Id id) external view returns (address lv);

    /**
     * Returns the total RA tokens that the vault at a given time, will be updated on every new issuance.(e.g total ra of dsId of 1 will be updated when Ds with dsId of 2 is issued)
     * Cork's team will use this snapshot value + internal tolerance(likelky would be 0.01%)to determine when the vault should resume deposits
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param dsId The DsId
     */
    function totalRaAt(Id id, uint256 dsId) external view returns (uint256);
}
