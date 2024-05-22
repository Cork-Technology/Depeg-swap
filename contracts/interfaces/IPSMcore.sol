// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/PSMKeyLib.sol";

interface IPSMcore {
    /// @notice Emitted when a new PSM is initialized with a given pair
    /// @param id The PSM id
    /// @param pa The address of the pegged asset
    /// @param ra The address of the redemption asset
    event Initialized(PsmId indexed id, address indexed pa, address indexed ra);

    /// @notice Emitted when a user deposits assets into a given PSM
    /// @param psmId The PSM id
    /// @param dsId The DS id
    /// @param depositor The address of the depositor
    /// @param amount The amount of the asset deposited
    event Deposited(
        PsmId indexed psmId,
        uint256 indexed dsId,
        address indexed depositor,
        uint256 amount
    );

    /// @notice Emitted when a new DS is issued for a given PSM
    /// @param psmId The PSM id
    /// @param dsId The DS id
    /// @param expiry The expiry of the DS
    event Issued(
        PsmId indexed psmId,
        uint256 indexed dsId,
        uint256 indexed expiry,
        address ds,
        address ct
    );

    /// @notice Emitted when a user redeems a DS for a given PSM
    /// @param psmId The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the DS redeemed
    event DsRedeemed(
        PsmId indexed psmId,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 amount
    );

    /// @notice Emitted when a user redeems a CT for a given PSM
    /// @param psmId The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the CT redeemed
    /// @param paReceived The amount of the pegged asset received
    /// @param raReceived The amount of the redemption asset received
    event CtRedeemed(
        PsmId indexed psmId,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 amount,
        uint256 paReceived,
        uint256 raReceived
    );

    /// @notice psm module is not initialized, i.e thrown when interacting with uninitialized module
    error Uinitialized();

    /// @notice psm module is already initialized, i.e thrown when trying to reinitialize a module
    error AlreadyInitialized();

    function initialize(address pa, address ra) external;

    function issueNewDs(PsmId id, uint256 expiry) external;

    function deposit(PsmId id, uint256 amount) external;

    function previewDeposit(
        PsmId id,
        uint256 amount
    ) external view returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId);

    function redeemWithRaWithDs(
        PsmId id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external;

    function previewRedeemWithDs(
        PsmId id,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 assets);

    function redeemWithCT(
        PsmId id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) external;

    function previewRedeemWithCt(
        PsmId id,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 paReceived, uint256 raReceived);
}
