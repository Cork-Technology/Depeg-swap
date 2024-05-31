// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PSMLib.sol";
import "./libraries/PairKey.sol";
import "./interfaces/IPSMcore.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IAssetFactory.sol";
import "./libraries/State.sol";

// TODO : make entrypoint that do not rely on permit with function overloading or different function altogether
contract PsmCore is IPSMcore {
    using PSMLibrary for State;
    using PairKeyLibrary for PairKey;

    mapping(PsmId => State) modules;

    address factory;

    // TODO : make this upgradeable
    constructor(address _factory) {
        factory = _factory;
    }

    modifier onlyInitialized(PsmId id) {
        if (!modules[id].isInitialized()) {
            revert Uinitialized();
        }
        _;
    }

    function _onlyValidAsset(address asset) internal view {
        if (IAssetFactory(factory).isDeployed(asset) == false) {
            revert InvalidAsset(asset);
        }
    }

    function getId(address pa, address ra) external pure returns (PsmId) {
        return PairKeyLibrary.initalize(pa, ra).toId();
    }

    // TODO : only allow to call this from config contract later or router
    function initialize(address pa, address ra, address wa) external override {
        _onlyValidAsset(wa);

        PairKey memory key = PairKeyLibrary.initalize(pa, ra);
        PsmId id = key.toId();

        State storage state = modules[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        state.initialize(key, wa);

        emit Initialized(id, pa, ra);
    }

    // TODO : only allow to call this from config contract later or router
    function issueNewDs(
        PsmId id,
        uint256 expiry,
        address ct,
        address ds
    ) external override onlyInitialized(id) {
        _onlyValidAsset(ct);
        _onlyValidAsset(ds);

        State storage state = modules[id];

        uint256 dsId = state.issueNewPair(ct, ds);

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

    function valueLocked(PsmId id) external view override returns (uint256) {
        State storage state = modules[id];
        return state.valueLocked();
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
