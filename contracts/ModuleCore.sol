// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PsmLib.sol";
import "./libraries/PairKey.sol";
import "./libraries/MathHelper.sol";
import "./interfaces/IPSMcore.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IAssetFactory.sol";
import "./libraries/State.sol";
import "./ModuleState.sol";
import "./interfaces/ICommon.sol";
import "./Psm.sol";
import "./Vault.sol";

// TODO : make entrypoint that do not rely on permit with function overloading or different function altogether
// TODO : make sync function to sync each pair of DS and CT balance
contract ModuleCore is PsmCore, Initialize, VaultCore {
    using PsmLibrary for State;
    using PairKeyLibrary for PairKey;

    constructor(address factory) ModuleState(factory) {}

    function getId(address pa, address ra) external pure returns (ModuleId) {
        return PairKeyLibrary.initalize(pa, ra).toId();
    }

    // TODO : only allow to call this from config contract later or router
    // TODO : handle this with the new abstract contract
    function initialize(address pa, address ra, address wa) external override {
        _onlyValidAsset(wa);

        PairKey memory key = PairKeyLibrary.initalize(pa, ra);
        ModuleId id = key.toId();

        State storage state = states[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        state.initialize(key, wa);

        emit Initialized(id, pa, ra);
    }

    // TODO : only allow to call this from config contract later or router
    function issueNewDs(
        ModuleId id,
        uint256 expiry,
        address ct,
        address ds
    ) external override onlyInitialized(id) {
        _onlyValidAsset(ct);
        _onlyValidAsset(ds);

        State storage state = states[id];

        uint256 prevIdx = state.globalAssetIdx++;
        uint256 idx = state.globalAssetIdx;
        state.issueNewPair(ct, ds, idx, prevIdx);

        emit Issued(id, idx, expiry, ds, ct);
    }
}
