// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/PairKey.sol";

interface IVault {
    /// @notice Emitted when a user deposits assets into a given Vault
    /// @param ModuleId The Module id that is used to reference both psm and lv of a given pair
    /// @param depositor The address of the depositor
    /// @param amount  The amount of the asset deposited
    event LvDeposited(
        ModuleId indexed ModuleId,
        address indexed depositor,
        uint256 amount
    );

    /// @notice Emitted when a user requests redemption of a given Vault
    /// @param ModuleId The Module id that is used to reference both psm and lv of a given pair
    /// @param redeemer The address of the redeemer
    event RedemptionRequested(
        ModuleId indexed ModuleId,
        address indexed redeemer
    );

    /// @notice Emitted when a user transfers redemption rights of a given Vault
    /// @param ModuleId The Module id that is used to reference both psm and lv of a given pair
    /// @param from The address of the previous owner of the redemption rights
    event RedemptionRightTransferred(
        ModuleId indexed ModuleId,
        address indexed from,
        address indexed to
    );

    /// @notice Emitted when a user redeems expired Lv
    /// @param ModuleId The Module id that is used to reference both psm and lv of a given pair
    /// @param receiver The address of the receiver
    /// @param amount The amount of the asset redeemed
    event LvRedeemExpired(
        ModuleId indexed ModuleId,
        address indexed receiver,
        uint256 amount
    );

    /// @notice Emitted when a user redeems Lv before expiry
    /// @param ModuleId The Module id that is used to reference both psm and lv of a given pair
    /// @param receiver The address of the receiver
    /// @param amount The amount of the asset redeemed
    event LvRedeemEarly(
        ModuleId indexed ModuleId,
        address indexed receiver,
        uint256 amount
    );

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     */
    function depositLv(ModuleId id, uint256 amount) external;

    /**
     * @notice Preview the amount of lv that will be deposited
     * @param amount The amount of the redemption asset(ra) to be deposited
     */
    function previewDeposit(uint256 amount) external pure returns (uint256 lv);

    /**
     * @notice Request redemption of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function requestRedemption(ModuleId id) external;

    /**
     * @notice Transfer redemption rights of a given vault at expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param to The address of the new owner of the redemption rights
     */
    function transferRedemptionRights(ModuleId id, address to) external;

    /**
     * @notice Redeem expired lv
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param receiver  The address of the receiver
     * @param amount The amount of the asset to be redeemed
     */
    function redeemExpiredLv(
        ModuleId id,
        address receiver,
        uint256 amount
    ) external;

    /**
     * @notice Redeem lv before expiry 
     * @param id The Module id that is used to reference both psm and lv of a given pair 
     * @param receiver The address of the receiver
     * @param amount The amount of the asset to be redeemed 
     */
    function redeemEarlyLv(
        ModuleId id,
        address receiver,
        uint256 amount
    ) external;
}
