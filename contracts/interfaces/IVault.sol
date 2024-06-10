// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/Pair.sol";

interface IVault {
    /// @notice Emitted when a user deposits assets into a given Vault
    /// @param id The Module id that is used to reference both psm and lv of a given pair
    /// @param depositor The address of the depositor
    /// @param amount  The amount of the asset deposited
    event LvDeposited(Id indexed id, address indexed depositor, uint256 amount);

    /// @notice Emitted when a user requests redemption of a given Vault
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param redeemer The address of the redeemer
    event RedemptionRequested(Id indexed Id, address indexed redeemer);

    /// @notice Emitted when a user transfers redemption rights of a given Vault
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param from The address of the previous owner of the redemption rights
    event RedemptionRightTransferred(
        Id indexed Id,
        address indexed from,
        address indexed to
    );

    /// @notice Emitted when a user redeems expired Lv
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param receiver The address of the receiver
    /// @param ra The amount of ra redeemed
    /// @param pa The amount of pa redeemed
    event LvRedeemExpired(
        Id indexed Id,
        address indexed receiver,
        uint256 ra,
        uint256 pa
    );

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
    function previewLvDeposit(
        uint256 amount
    ) external pure returns (uint256 lv);

    /**
     * @notice Request redemption of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function requestRedemption(Id id) external;

    /**
     * @notice Transfer redemption rights of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param to The address of the new owner of the redemption rights
     */
    function transferRedemptionRights(Id id, address to) external;

    /**
     * @notice Redeem expired lv
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver  The address of the receiver
     * @param amount The amount of the asset to be redeemed
     */
    function redeemExpiredLv(Id id, address receiver, uint256 amount) external;

    /**
     * @notice Redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed
     */
    function redeemEarlyLv(Id id, address receiver, uint256 amount) external;
}
