// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/PsmLib.sol";
import "../libraries/VaultLib.sol";
import "../libraries/Pair.sol";
import "../libraries/MathHelper.sol";
import "../interfaces/IPSMcore.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IAssetFactory.sol";
import "../libraries/State.sol";
import "./ModuleState.sol";
import "../interfaces/ICommon.sol";
import "./Psm.sol";
import "./Vault.sol";
import "../interfaces/Init.sol";
import "../interfaces/uniswap-v2/factory.sol";
import "./flash-swaps/FlashSwapRouter.sol";

// TODO : make entrypoint that do not rely on permit with function overloading or different function altogether
contract ModuleCore is PsmCore, Initialize, VaultCore {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    constructor(
        address swapAssetFactory,
        address ammFactory,
        address flashSwapRouter,
        address ammRouter,
        address config
    )
        ModuleState(
            swapAssetFactory,
            ammFactory,
            flashSwapRouter,
            ammRouter,
            config
        )
    {}

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
        // TODO : maybe remove this threshold
        uint256 lvAmmWaDepositThreshold,
        uint256 lvAmmCtDepositThreshold
    ) external override onlyConfig {
        Pair memory key = PairLibrary.initalize(pa, ra);
        Id id = key.toId();

        State storage state = states[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        IAssetFactory factory = IAssetFactory(swapAssetFactory);

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
        uint256 exchangeRates,
        uint256 repurchaseFeePrecentage
    ) external override onlyConfig onlyInitialized(id) {
        State storage state = states[id];

        address ra = state.info.pair1;

        (address ct, address ds) = IAssetFactory(swapAssetFactory)
            .deploySwapAssets(
                ra,
                state.info.pair0,
                address(this),
                expiry,
                exchangeRates
            );

        uint256 prevIdx = state.globalAssetIdx++;
        uint256 idx = state.globalAssetIdx;

        address ammPair = getAmmFactory().createPair(ra, ct);

        PsmLibrary.onNewIssuance(
            state,
            ct,
            ds,
            ammPair,
            idx,
            prevIdx,
            repurchaseFeePrecentage
        );

        // TODO : 0 for initial reserve for now, will be calculated later when rollover stragegy is implemented
        getRouterCore().onNewIssuance(id, idx, ds, ammPair, 0, ra, ct);

        VaultLibrary.onNewIssuance(
            state,
            prevIdx,
            getRouterCore(),
            getAmmRouter()
        );

        emit Issued(id, idx, expiry, ds, ct, ammPair);
    }

    function updateRepurchaseFeeRate(
        Id id,
        uint256 newRepurchaseFeePrecentage
    ) external onlyConfig {
        State storage state = states[id];
        PsmLibrary.updateRepurchaseFeePercentage(state, newRepurchaseFeePrecentage);

        emit RepurchaseFeeRateUpdated(id, newRepurchaseFeePrecentage);
    }

    function updateEarlyRedemptionFeeRate(
        Id id,
        uint256 newEarlyRedemptionFeeRate
    ) external onlyConfig {
        State storage state = states[id];
        VaultConfigLibrary.updateFee(
            state.vault.config,
            newEarlyRedemptionFeeRate
        );

        emit RepurchaseFeeRateUpdated(id, newEarlyRedemptionFeeRate);
    }

    function updatePoolsStatus(
        Id id,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    ) external onlyConfig {
        State storage state = states[id];
        PsmLibrary.updatePoolsStatus(
            state,          
            isPSMDepositPaused,
            isPSMWithdrawalPaused,
            isLVDepositPaused,
            isLVWithdrawalPaused
        );

        emit PoolsStatusUpdated(
            id,
            isPSMDepositPaused,
            isPSMWithdrawalPaused,
            isLVDepositPaused,
            isLVWithdrawalPaused
        );
    }

    function lastDsId(Id id) external view override returns (uint256 dsId) {
        return states[id].globalAssetIdx;
    }

    function underlyingAsset(
        Id id
    ) external view override returns (address ra, address pa) {
        (ra, pa) = states[id].info.underlyingAsset();
    }

    function swapAsset(
        Id id,
        uint256 dsId
    ) external view override returns (address ct, address ds) {
        ct = states[id].ds[dsId].ct;
        ds = states[id].ds[dsId]._address;
    }
}
