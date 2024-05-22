// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PSMLib.sol";
import "./libraries/PSMKeyLib.sol";
import "./interfaces/IPSMcore.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract PsmCore is IPSMcore {
    using PSMLibrary for State;
    using PsmKeyLibrary for PsmKey;

    mapping(PsmId => State) public modules;

    function getId(address pa, address ra) external pure returns (PsmId) {
        return PsmKeyLibrary.initalize(pa, ra).toId();
    }

    constructor() {}

    modifier onlyInitialized(PsmId id) {
        if (!modules[id].isInitialized()) {
            revert Uinitialized();
        }
        _;
    }

    function initialize(address pa, address ra) external override {
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

    function issueNewDs(
        PsmId id,
        uint256 expiry
    ) external override onlyInitialized(id) {
        State storage state = modules[id];
        (uint256 dsId, address ds, address ct) = state.issueNewPair(expiry);

        emit Issued(id, dsId, expiry, ds, ct);
    }

    function deposit(
        PsmId id,
        uint256 amount
    ) external override onlyInitialized(id) {
        State storage state = modules[id];
        uint256 dsId = state.deposit(msg.sender, amount);
        emit Deposited(id, dsId, msg.sender, amount);
    }

    function previewDeposit(
        PsmId id,
        uint256 amount
    )
        external
        view
        override
        onlyInitialized(id)
        returns (uint256 ctReceived, uint256 dsReceived, uint256 dsId)
    {
        State storage state = modules[id];
        (ctReceived, dsReceived, dsId) = state.previewDeposit(amount);
    }

    function redeemWithRaWithDs(
        PsmId id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external override onlyInitialized(id) {
        State storage state = modules[id];

        emit DsRedeemed(id, dsId, msg.sender, amount);

        state.redeemWithDs(msg.sender, amount, dsId, rawDsPermitSig, deadline);
    }

    function previewRedeemWithDs(
        PsmId id,
        uint256 dsId,
        uint256 amount
    ) external view override onlyInitialized(id) returns (uint256 assets) {
        State storage state = modules[id];
        assets = state.previewRedeemWithDs(amount, dsId);
    }

    function redeemWithCT(
        PsmId id,
        uint256 dsId,
        uint256 amount,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) external override onlyInitialized(id) {
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
        override
        onlyInitialized(id)
        returns (uint256 paReceived, uint256 raReceived)
    {
        State storage state = modules[id];
        (paReceived, raReceived) = state.previewRedeemWithCt(amount, dsId);
    }
}
