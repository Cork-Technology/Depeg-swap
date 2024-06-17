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

// TODO : make entrypoint that do not rely on permit with function overloading or different function altogether
contract ModuleCore is PsmCore, Initialize, VaultCore {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    constructor(address factory) ModuleState(factory) {}

    function getId(address pa, address ra) external pure returns (Id) {
        return PairLibrary.initalize(pa, ra).toId();
    }

    // TODO : only allow to call this from config contract later or router
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

        address wa = factory.deployWrappedAsset(ra);
        address lv = factory.deployLv(ra, pa, wa, address(this));

        PsmLibrary.initialize(state, key, wa);
        VaultLibrary.initialize(
            state.vault,
            lv,
            lvFee,
            lvAmmWaDepositThreshold,
            lvAmmCtDepositThreshold,
            wa
        );

        emit Initialized(id, pa, ra, wa, lv);
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
        address wa = state.psmBalances.wa._address;

        (address _ct, address _ds) = IAssetFactory(_factory).deploySwapAssets(
            pa,
            ra,
            wa,
            address(this),
            expiry,
            exchangeRates
        );

        uint256 prevIdx = state.globalAssetIdx++;
        uint256 idx = state.globalAssetIdx;
        state.issueNewPair(_ct, _ds, idx, prevIdx);

        emit Issued(id, idx, expiry, _ds, _ct);
    }
}
