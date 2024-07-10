// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PsmLib.sol";
import "./libraries/VaultLib.sol";
import "./libraries/Pair.sol";
import "./libraries/MathHelper.sol";
import "./interfaces/IPSMcore.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IAssetFactory.sol";
import "./libraries/State.sol";
import "./ModuleState.sol";
import "./interfaces/ICommon.sol";
import "./Psm.sol";
import "./Vault.sol";
import "./interfaces/Init.sol";
import "./dev/LvDev.sol";
import "./dev/PsmDev.sol";

// TODO : make entrypoint that do not rely on permit with function overloading or different function altogether
// TODO : make sync function to sync each pair of DS and CT balance
contract ModuleCore is PsmCore, Initialize, VaultCore, LvDev, PsmDev {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    constructor(address factory) ModuleState(factory) {}

    function getId(address pa, address ra) external pure returns (Id) {
        return PairLibrary.initalize(pa, ra).toId();
    }

    // TODO : only allow to call this from config contract later or router
    // TODO : make a pair id associated with it's interval.
    // TODO : auto issue.
    function initialize(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 lvAmmWaDepositThreshold,
        uint256 lvAmmCtDepositThreshold
    ) external override {
        Pair memory key = PairLibrary.initalize(pa, ra);
        Id id = key.toId();

        State storage state = states[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        IAssetFactory factory = IAssetFactory(_factory);

        address lv = factory.deployLv(ra, pa, address(this));

        PsmLibrary.initialize(state, key);
        VaultLibrary.initialize(
            state.vault,
            lv,
            lvFee,
            lvAmmWaDepositThreshold,
            lvAmmCtDepositThreshold,
            ra
        );

        emit Initialized(id, pa, ra, lv);
    }

    // TODO : only allow to call this from config contract later or router
    function issueNewDs(
        Id id,
        uint256 expiry,
        uint256 exchangeRates
    ) external override onlyInitialized(id) {
        State storage state = states[id];

        address pa = state.info.pair0;
        address ra = state.info.pair1;

        (address _ct, address _ds) = IAssetFactory(_factory).deploySwapAssets(
            ra,
            pa,
            address(this),
            expiry,
            exchangeRates
        );

        uint256 prevIdx = state.globalAssetIdx++;
        uint256 idx = state.globalAssetIdx;

        PsmLibrary.issueNewPair(state, _ct, _ds, idx, prevIdx);
        VaultLibrary.onNewIssuanceAndExpiry(state, prevIdx);

        emit Issued(id, idx, expiry, _ds, _ct);
    }

    function lastDsId(Id id) external view override returns (uint256 dsId) {
        return states[id].globalAssetIdx;
    }
}
