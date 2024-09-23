pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";

/**
 * @title IVault Interface
 * @author Cork Team
 * @notice IVault interface for VaultCore contract
 */
interface IVault {
    /// @notice Emitted when a user deposits assets into a given Vault
    /// @param id The Module id that is used to reference both psm and lv of a given pair
    /// @param depositor The address of the depositor
    /// @param amount  The amount of the asset deposited
    event LvDeposited(Id indexed id, address indexed depositor, uint256 amount);

    /// @notice Emitted when a user redeems Lv before expiry
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param receiver The address of the receiver
    /// @param amount The amount of the asset redeemed
    /// @param fee The total fee charged for early redemption
    /// @param feePrecentage The fee precentage for early redemption, denominated in 1e18 (e.g 100e18 = 100%)
    event LvRedeemEarly(
        Id indexed Id,
        address indexed redeemer,
        address indexed receiver,
        uint256 amount,
        uint256 fee,
        uint256 feePrecentage
    );

    /// @notice Emitted when a early redemption fee is updated for a given Vault
    /// @param Id The State id
    /// @param newEarlyRedemptionFee The new early redemption rate
    event EarlyRedemptionFeeUpdated(Id indexed Id, uint256 indexed newEarlyRedemptionFee);

    event LvRedeemedWithPA(Id indexed id, address indexed redeemer, uint256 pa);

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     */
    function depositLv(Id id, uint256 amount) external returns (uint256 received);

    function previewRedeemPaWithLv(Id id, uint256 amount) external view returns (uint256 pa);

    function redeemablePA(Id id) external view returns (uint256);

    function redeemPaWithLv(Id id, uint256 amount) external returns (uint256 received);

    /**
     * @notice Preview the amount of lv that will be deposited
     * @param amount The amount of the redemption asset(ra) to be deposited
     */
    function previewLvDeposit(Id id, uint256 amount) external view returns (uint256 lv);

    /**
     * @notice Redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed
     * @param rawLvPermitSig Raw signature for LV approval permit
     * @param deadline deadline for Approval permit signature
     */
    function redeemEarlyLv(
        Id id,
        address receiver,
        uint256 amount,
        bytes memory rawLvPermitSig,
        uint256 deadline,
        uint256 amountOutMin
    ) external returns (uint256 received, uint256 fee, uint256 feePrecentage);

    /**
     * @notice Redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed
     * @param amountOutMin The minimum amount of the asset to be received
     */
    function redeemEarlyLv(Id id, address receiver, uint256 amount, uint256 amountOutMin)
        external
        returns (uint256 received, uint256 fee, uint256 feePrecentage);

    /**
     * @notice preview redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the asset to be redeemed
     */
    function previewRedeemEarlyLv(Id id, uint256 amount)
        external
        view
        returns (uint256 received, uint256 fee, uint256 feePrecentage);

    /**
     * Returns the early redemption fee percentage
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function earlyRedemptionFee(Id id) external view returns (uint256);

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
}
