// SPDX-License-Identifier: BUSL-1.1
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
import {AmmId, toAmmId} from "Cork-Hook/lib/State.sol";

/**
 * @title ModuleCore Contract
 * @author Cork Team
 * @notice Modulecore contract for integrating abstract modules like PSM and Vault contracts
 */
contract ModuleCore is OwnableUpgradeable, UUPSUpgradeable, PsmCore, Initialize, VaultCore {
    /// @notice __gap variable to prevent storage collisions
    uint256[49] __gap;

    using PsmLibrary for State;
    using PairLibrary for Pair;

    /// @notice Initializer function for upgradeable contracts
    function initialize(address _swapAssetFactory, address _ammHook, address _flashSwapRouter, address _config)
        external
        initializer
    {
        if (
            _swapAssetFactory == address(0) || _ammHook == address(0) || _flashSwapRouter == address(0)
                || _config == address(0)
        ) {
            revert ZeroAddress();
        }

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        initializeModuleState(_swapAssetFactory, _ammHook, _flashSwapRouter, _config);
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

    function getId(address pa, address ra, uint256 expiryInterva) external pure returns (Id) {
        return PairLibrary.initalize(pa, ra, expiryInterva).toId();
    }

    function initializeModuleCore(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 initialDsPrice,
        uint256 psmBaseRedemptionFeePercentage,
        uint256 expiryInterval
    ) external override onlyConfig {
        Pair memory key = PairLibrary.initalize(pa, ra, expiryInterval);
        Id id = key.toId();

        State storage state = states[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        IAssetFactory assetsFactory = IAssetFactory(SWAP_ASSET_FACTORY);

        address lv = assetsFactory.deployLv(ra, pa, address(this), expiryInterval);

        PsmLibrary.initialize(state, key, psmBaseRedemptionFeePercentage);
        VaultLibrary.initialize(state.vault, lv, lvFee, ra, initialDsPrice);
        emit InitializedModuleCore(id, pa, ra, lv, expiryInterval);
    }

    function issueNewDs(
        Id id,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        // won't have effect on first issuance
        uint256 rolloverPeriodInblocks,
        uint256 ammLiquidationDeadline
    ) external override onlyConfig onlyInitialized(id) {
        if (repurchaseFeePercentage > 5 ether) {
            revert InvalidFees();
        }

        State storage state = states[id];

        Pair storage info = state.info;


        (address ct, address ds) = IAssetFactory(SWAP_ASSET_FACTORY).deploySwapAssets(
            info.ra, state.info.pa, address(this), info.expiryInterval, exchangeRates, state.globalAssetIdx + 1
        );

        // avoid stack to deep error
        _initOnNewIssuance(id, repurchaseFeePercentage, ct, ds, info.expiryInterval);
        // avoid stack to deep error
        getRouterCore().setDecayDiscountAndRolloverPeriodOnNewIssuance(
            id, decayDiscountRateInDays, rolloverPeriodInblocks
        );
        VaultLibrary.onNewIssuance(
            state, state.globalAssetIdx - 1, getRouterCore(), getAmmRouter(), ammLiquidationDeadline
        );
    }

    function _initOnNewIssuance(Id id, uint256 repurchaseFeePercentage, address ct, address ds, uint256 _expiryInterval)
        internal
    {
        State storage state = states[id];

        address ra = state.info.ra;
        uint256 prevIdx = state.globalAssetIdx++;
        uint256 idx = state.globalAssetIdx;

        PsmLibrary.onNewIssuance(state, ct, ds, idx, prevIdx, repurchaseFeePercentage);

        // TODO : must handle changes in flash swap router later
        getRouterCore().onNewIssuance(id, idx, ds, ra, ct);

        // TODO : place holder, must change to the id later
        emit Issued(id, idx, block.timestamp + _expiryInterval, ds, ct, AmmId.unwrap(toAmmId(ra, ct)));
    }

    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external onlyConfig {
        State storage state = states[id];
        PsmLibrary.updateRepurchaseFeePercentage(state, newRepurchaseFeePercentage);

        emit RepurchaseFeeRateUpdated(id, newRepurchaseFeePercentage);
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
        bool isPSMRepurchasePaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    ) external onlyConfig {
        State storage state = states[id];
        PsmLibrary.updatePoolsStatus(
            state,
            isPSMDepositPaused,
            isPSMWithdrawalPaused,
            isPSMRepurchasePaused,
            isLVDepositPaused,
            isLVWithdrawalPaused
        );

        emit PoolsStatusUpdated(
            id,
            isPSMDepositPaused,
            isPSMWithdrawalPaused,
            isPSMRepurchasePaused,
            isLVDepositPaused,
            isLVWithdrawalPaused
        );
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
     * @param newPsmBaseRedemptionFeePercentage new value of fees
     */
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage)
        external
        onlyConfig
    {
        if (newPsmBaseRedemptionFeePercentage > 5 ether) {
            revert InvalidFees();
        }
        State storage state = states[id];
        PsmLibrary.updatePSMBaseRedemptionFeePercentage(state, newPsmBaseRedemptionFeePercentage);
        emit PsmBaseRedemptionFeePercentageUpdated(id, newPsmBaseRedemptionFeePercentage);
    }

    function expiry(Id id) external view override returns (uint256 _expiry) {
        _expiry = PsmLibrary.nextExpiry(states[id]);
    }
}
