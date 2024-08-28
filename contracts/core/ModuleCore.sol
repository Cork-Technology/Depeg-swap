pragma solidity 0.8.24;

import {PsmLibrary} from "../libraries/PsmLib.sol";
import {VaultLibrary, VaultConfigLibrary} from "../libraries/VaultLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {IAssetFactory} from "../interfaces/IAssetFactory.sol";
import {State} from "../libraries/State.sol";
import {ModuleState} from "./ModuleState.sol";
import {PsmCore} from "./Psm.sol";
import {VaultCore} from "./Vault.sol";
import {Initialize} from "../interfaces/Init.sol";

/**
 * @title ModuleCore Contract
 * @author Cork Team
 * @notice Modulecore contract for integrating abstract modules like PSM and Vault contracts
 */
contract ModuleCore is PsmCore, Initialize, VaultCore {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    constructor(
        address _swapAssetFactory,
        address _ammFactory,
        address _flashSwapRouter,
        address _ammRouter,
        address _config,
        uint256 _psmBaseRedemptionFeePrecentage
    )
        ModuleState(_swapAssetFactory, _ammFactory, _flashSwapRouter, _ammRouter, _config, _psmBaseRedemptionFeePrecentage)
    {}

    function getId(address pa, address ra) external pure returns (Id) {
        return PairLibrary.initalize(pa, ra).toId();
    }

    function initialize(address pa, address ra, uint256 lvFee, uint256 initialDsPrice) external override onlyConfig {
        Pair memory key = PairLibrary.initalize(pa, ra);
        Id id = key.toId();

        State storage state = states[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        IAssetFactory assetsFactory = IAssetFactory(SWAP_ASSET_FACTORY);

        address lv = assetsFactory.deployLv(ra, pa, address(this));

        PsmLibrary.initialize(state, key);
        VaultLibrary.initialize(state.vault, lv, lvFee, ra, initialDsPrice);

        emit Initialized(id, pa, ra, lv);
    }

    function issueNewDs(Id id, uint256 expiry, uint256 exchangeRates, uint256 repurchaseFeePrecentage)
        external
        override
        onlyConfig
        onlyInitialized(id)
    {
        if (repurchaseFeePrecentage > 5 ether) {
            revert InvalidFees();
        }
        State storage state = states[id];

        address ra = state.info.pair1;

        uint256 prevIdx = state.globalAssetIdx++;
        uint256 idx = state.globalAssetIdx;

        (address ct, address ds) = IAssetFactory(SWAP_ASSET_FACTORY).deploySwapAssets(
            ra, state.info.pair0, address(this), expiry, exchangeRates
        );

        address ammPair = getAmmFactory().createPair(ra, ct);

        PsmLibrary.onNewIssuance(state, ct, ds, ammPair, idx, prevIdx, repurchaseFeePrecentage);

        getRouterCore().onNewIssuance(id, idx, ds, ammPair, 0, ra, ct);

        VaultLibrary.onNewIssuance(state, prevIdx, getRouterCore(), getAmmRouter());

        emit Issued(id, idx, expiry, ds, ct, ammPair);
    }

    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePrecentage) external onlyConfig {
        State storage state = states[id];
        PsmLibrary.updateRepurchaseFeePercentage(state, newRepurchaseFeePrecentage);

        emit RepurchaseFeeRateUpdated(id, newRepurchaseFeePrecentage);
    }

    function updateEarlyRedemptionFeeRate(Id id, uint256 newEarlyRedemptionFeeRate) external onlyConfig {
        State storage state = states[id];
        VaultConfigLibrary.updateFee(state.vault.config, newEarlyRedemptionFeeRate);

        emit EarlyRedemptionFeeRateUpdated(id, newEarlyRedemptionFeeRate);
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
            state, isPSMDepositPaused, isPSMWithdrawalPaused, isLVDepositPaused, isLVWithdrawalPaused
        );

        emit PoolsStatusUpdated(id, isPSMDepositPaused, isPSMWithdrawalPaused, isLVDepositPaused, isLVWithdrawalPaused);
    }

    /**
     * @notice Get the last DS id issued for a given module, the returned DS doesn't guarantee to be active
     * @param id The current module id
     * @return dsId The current effective DS id
     *
     */
    function lastDsId(Id id) external view override returns (uint256 dsId) {
        return states[id].globalAssetIdx;
    }

    /**
     * @notice returns the address of the underlying RA and PA token
     * @param id the id of PSM
     * @return ra address of the underlying RA token
     * @return pa address of the underlying PA token
     */
    function underlyingAsset(Id id) external view override returns (address ra, address pa) {
        (ra, pa) = states[id].info.underlyingAsset();
    }

    /**
     * @notice returns the address of CT and DS associated with a certain DS id
     * @param id the id of PSM
     * @param dsId the DS id
     * @return ct address of the CT token
     * @return ds address of the DS token
     */
    function swapAsset(Id id, uint256 dsId) external view override returns (address ct, address ds) {
        ct = states[id].ds[dsId].ct;
        ds = states[id].ds[dsId]._address;
    }

    /**
     * @notice update value of PSMBaseRedemption fees
     * @param newPsmBaseRedemptionFeePrecentage new value of fees
     */
    function updatePsmBaseRedemptionFeePrecentage(uint256 newPsmBaseRedemptionFeePrecentage) external onlyConfig {
        if (newPsmBaseRedemptionFeePrecentage > 5 ether) {
            revert InvalidFees();
        }
        psmBaseRedemptionFeePrecentage = newPsmBaseRedemptionFeePrecentage;
    }
}
