// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PSMLib.sol";
import "./libraries/PSMKeyLib.sol";
import "./interfaces/IERC20Metadata.sol";

// TODO : move event, errors, docs, and function declaration to interface

contract PsmCore {
    using PSMLibrary for State;
    using PsmKeyLibrary for PsmKey;

    /// @notice Emitted when a new PSM is initialized with a given pair
    /// @param id The PSM id
    /// @param pa The address of the pegged asset
    /// @param ra The address of the redemption asset
    event Initialized(PsmId indexed id, address indexed pa, address indexed ra);

    /// @notice Emitted when a new DS is issued for a given PSM
    /// @param psmId The PSM id
    /// @param dsId The DS id
    /// @param expiry The expiry of the DS
    event Issued(
        PsmId indexed psmId,
        uint256 indexed dsId,
        uint256 indexed expiry
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

    mapping(PsmId => PSMLibrary.State) public modules;

    constructor() {}

    modifier onlyInitialized(PsmId id) {
        if (!modules[id].isInitialized()) {
            revert Uinitialized();
        }
        _;
    }

    function initialize(address pa, address ra) external {
        PsmKey memory key = PsmKeyLibrary.initalize(pa, ra);
        PsmId id = key.toId();

        (string memory _pa, string memory _ra) = (
            IERC20Metadata(pa).symbol(),
            IERC20Metadata(ra).symbol()
        );
        string memory pairname = string(abi.encodePacked(_pa, "-", _ra));

        State storage state = modules[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        state.initialize(key, pairname);

        emit Initialized(id, pa, ra);
    }

    function issueNewDs(PsmId id, uint256 expiry) external onlyInitialized(id) {
        State storage state = modules[id];
        uint256 dsId = state.issueNewPair(expiry);

        emit Issued(id, dsId, expiry);
    }

    function deposit(
        PsmId id,
        uint256 dsId,
        uint256 amount
    ) external onlyInitialized(id) {
        State storage state = modules[id];
        state.deposit(msg.sender, amount, dsId);
    }

    function previewDeposit(
        PsmId id,
        uint256 dsId,
        uint256 amount
    )
        external
        view
        onlyInitialized(id)
        returns (uint256 ctReceived, uint256 dsReceived)
    {
        State storage state = modules[id];
        (ctReceived, dsReceived) = state.previewDeposit(amount, dsId);
    }

    function redeemWithDs(
        PsmId id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external onlyInitialized(id) {
        State storage state = modules[id];

        emit DsRedeemed(id, dsId, msg.sender, amount);

        state.redeemWithDs(msg.sender, amount, dsId, rawDsPermitSig, deadline);
    }

    function previewRedeemWithDs(
        uint256 dsId,
        uint256 amount
    ) external view onlyInitialized(id) returns (uint256 assets) {
        State storage state = modules[id];
        assets = state.previewRedeemWithDs(amount, dsId);
    }

    function redeemWithCT(
        PsmId id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) external onlyInitialized(id) {
        State storage state = modules[id];

        (uint256 accruedPa, uint256 accruedRa) = state.redeemWithCt(
            msg.sender,
            amount,
            dsId,
            rawCtPermitSig,
            deadline
        );

        emit CtRedeemed(id, dsId, msg.sender, amount, accruedPa, accruedRa);
    }

    function previewRedeemWithCt(
        PsmId id,
        uint256 dsId,
        uint256 amount
    )
        external
        view
        onlyInitialized(id)
        returns (uint256 paReceived, uint256 raReceived)
    {
        State storage state = modules[id];
        (paReceived, raReceived) = state.previewRedeemWithCt(amount, dsId);
    }
}
