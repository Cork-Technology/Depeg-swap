pragma solidity 0.8.24;

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

    /// @notice Emitted when a user requests redemption of a given Vault
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the asset to be redeemed
    event RedemptionRequested(Id indexed Id, address indexed redeemer, uint256 amount);

    /// @notice Emitted when a user transfers redemption rights of a given Vault
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param from The address of the previous owner of the redemption rights
    /// @param to The address of the new owner of the redemption rights
    event RedemptionRightTransferred(Id indexed Id, address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when a user redeems expired Lv
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param receiver The address of the receiver
    /// @param ra The amount of ra redeemed
    /// @param pa The amount of pa redeemed
    event LvRedeemExpired(Id indexed Id, address indexed receiver, uint256 ra, uint256 pa);

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

    /// @notice Emitted when a user cancels a redemption request
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the asset to be redeemed
    event RedemptionRequestCancelled(Id indexed Id, address indexed redeemer, uint256 amount);

    /// @notice Emitted when a early redemption fee is updated for a given Vault
    /// @param Id The State id
    /// @param newEarlyRedemptionFee The new early redemption rate
    event EarlyRedemptionFeeUpdated(Id indexed Id, uint256 indexed newEarlyRedemptionFee);

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     */
    function depositLv(Id id, uint256 amount) external;

    /**
     * @notice Preview the amount of lv that will be deposited
     * @param amount The amount of the redemption asset(ra) to be deposited
     */
    function previewLvDeposit(Id id, uint256 amount) external view returns (uint256 lv);

    /**
     * @notice Request redemption of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param rawLvPermitSig  The signature for Lv transfer permitted by user
     * @param deadline  The deadline timestamp os signature expiry
     */
    function requestRedemption(Id id, uint256 amount, bytes memory rawLvPermitSig, uint256 deadline) external;

    /**
     * @notice Request redemption of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function requestRedemption(Id id, uint256 amount) external;

    /**
     * @notice Transfer redemption rights of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param to The address of the new owner of the redemption rights
     * @param amount The amount of the user locked LV token to be transferred
     */
    function transferRedemptionRights(Id id, address to, uint256 amount) external;

    /**
     * @notice Redeem expired lv, when there's no active DS issuance, there's no cap on the amount of lv that can be redeemed.
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver  The address of the receiver
     * @param amount The amount of the asset to be redeemed
     * @param rawLvPermitSig  The signature for Lv transfer permitted by user
     * @param deadline  The deadline timestamp os signature expiry
     */
    function redeemExpiredLv(Id id, address receiver, uint256 amount, bytes memory rawLvPermitSig, uint256 deadline)
        external;

    /**
     * @notice Redeem expired lv, when there's no active DS issuance, there's no cap on the amount of lv that can be redeemed.
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver  The address of the receiver
     * @param amount The amount of the asset to be redeemed
     */
    function redeemExpiredLv(Id id, address receiver, uint256 amount) external;

    /**
     * @notice preview redeem expired lv
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the asset to be redeemed
     * @return attributedRa The amount of ra that will be redeemed
     * @return attributedPa The amount of pa that will be redeemed
     * @return approvedAmount The amount of lv needed to be approved before redeeming,
     * this is necessary when the user doesn't have enough locked LV token to redeem the full amount
     */
    function previewRedeemExpiredLv(Id id, uint256 amount)
        external
        view
        returns (uint256 attributedRa, uint256 attributedPa, uint256 approvedAmount);

    /**
     * @notice Redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed
     * @param rawLvPermitSig Raw signature for LV approval permit
     * @param deadline deadline for Approval permit signature
     */
    function redeemEarlyLv(Id id, address receiver, uint256 amount, bytes memory rawLvPermitSig, uint256 deadline)
        external;

    /**
     * @notice Redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed
     */
    function redeemEarlyLv(Id id, address receiver, uint256 amount) external;

    /**
     * @notice Get the amount of locked lv for a given user
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param user The address of the user
     */
    function lockedLvfor(Id id, address user) external view returns (uint256 locked);

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
     * Returns the amount of RA and PA reserved for user withdrawal
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function reservedUserWithdrawal(Id id) external view returns (uint256 reservedRa, uint256 reservedPa);

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
}
