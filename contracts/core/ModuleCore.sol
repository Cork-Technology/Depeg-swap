pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PsmLibrary} from "../libraries/PsmLib.sol";
import {VaultLibrary, VaultConfigLibrary} from "../libraries/VaultLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {IAssetFactory} from "../interfaces/IAssetFactory.sol";
import {State} from "../libraries/State.sol";
import {ModuleState} from "./ModuleState.sol";
import {PsmCore} from "./Psm.sol";
import {VaultCore} from "./Vault.sol";
import {Initialize} from "../interfaces/Init.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @title ModuleCore Contract
 * @author Cork Team
 * @notice Modulecore contract for integrating abstract modules like PSM and Vault contracts
 */
abstract contract ModuleCore is OwnableUpgradeable, UUPSUpgradeable, PsmCore, Initialize, VaultCore {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    /// @notice Initializer function for upgradeable contracts
    function initialize(
        address _swapAssetFactory,
        address _ammFactory,
        address _flashSwapRouter,
        address _ammRouter,
        address _config
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        initializeModuleState(_swapAssetFactory, _ammFactory, _flashSwapRouter, _ammRouter, _config);
    }

    /// @notice Authorization function for UUPS proxy upgrades
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _msgSender() internal view override(ContextUpgradeable, Context) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, Context) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view override(ContextUpgradeable, Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    function getId(address pa, address ra) external pure returns (Id) {
        return PairLibrary.initalize(pa, ra).toId();
    }

    function initialize(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 initialDsPrice,
        uint256 _psmBaseRedemptionFeePercentage
    ) external onlyConfig {
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
        state.psm.psmBaseRedemptionFeePrecentage = _psmBaseRedemptionFeePercentage;

        emit InitializedModuleCore(id, pa, ra, lv);
    }

    function issueNewDs(
        Id id,
        uint256 expiry,
        uint256 exchangeRates,
        uint256 repurchaseFeePrecentage,
        uint256 decayDiscountRateInDays,
        // won't have effect on first issuance
        uint256 rolloverPeriodInblocks
    ) external override onlyConfig onlyInitialized(id) {
        if (repurchaseFeePrecentage > 5 ether) {
            revert InvalidFees();
        }

        State storage state = states[id];

        address ra = state.info.pair1;

        (address ct, address ds) = IAssetFactory(SWAP_ASSET_FACTORY).deploySwapAssets(
            ra, state.info.pair0, address(this), expiry, exchangeRates
        );

        // avoid stack to deep error
        _initOnNewIssuance(id, repurchaseFeePrecentage, ra, ct, ds, expiry);
        // avoid stack to deep error
        getRouterCore().setDecayDiscountAndRolloverPeriodOnNewIssuance(
            id, decayDiscountRateInDays, rolloverPeriodInblocks
        );
        VaultLibrary.onNewIssuance(state, state.globalAssetIdx - 1, getRouterCore(), getAmmRouter());
    }

    function _initOnNewIssuance(
        Id id,
        uint256 repurchaseFeePrecentage,
        address ra,
        address ct,
        address ds,
        uint256 expiry
    ) internal {
        State storage state = states[id];

        uint256 prevIdx = state.globalAssetIdx++;
        uint256 idx = state.globalAssetIdx;

        address ammPair = getAmmFactory().createPair(ra, ct);

        PsmLibrary.onNewIssuance(state, ct, ds, ammPair, idx, prevIdx, repurchaseFeePrecentage);

        getRouterCore().onNewIssuance(id, idx, ds, ammPair, 0, ra, ct);

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
    function updatePsmBaseRedemptionFeePrecentage(Id id, uint256 newPsmBaseRedemptionFeePrecentage)
        external
        onlyConfig
    {
        if (newPsmBaseRedemptionFeePrecentage > 5 ether) {
            revert InvalidFees();
        }
        State storage state = states[id];
        PsmLibrary.updatePSMBaseRedemptionFeePrecentage(state, newPsmBaseRedemptionFeePrecentage);
        emit PsmBaseRedemptionFeePrecentageUpdated(id, newPsmBaseRedemptionFeePrecentage);
    }
}
