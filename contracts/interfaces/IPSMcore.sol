// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/Pair.sol";

interface IPSMcore {
    /// @notice Emitted when a user deposits assets into a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param depositor The address of the depositor
    /// @param amount The amount of the asset deposited
    event PsmDeposited(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed depositor,
        uint256 amount
    );

    /// @notice Emitted when a user redeems a DS for a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the DS redeemed
    event DsRedeemed(
        Id indexed Id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 amount
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

    function depositPsm(Id id, uint256 amount) external;

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

    function valueLocked(Id id) external view returns (uint256);
}
