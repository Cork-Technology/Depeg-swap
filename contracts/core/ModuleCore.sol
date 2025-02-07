// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PsmLibrary} from "../libraries/PsmLib.sol";
import {VaultLibrary} from "../libraries/VaultLib.sol";
import {Id, Pair, PairLibrary} from "../libraries/Pair.sol";
import {IAssetFactory} from "../interfaces/IAssetFactory.sol";
import {State} from "../libraries/State.sol";
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
    uint256[49] private __gap;

    using PsmLibrary for State;
    using PairLibrary for Pair;

    constructor() {
        _disableInitializers();
    }

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

    function setWithdrawalContract(address _withdrawalContract) external {
        onlyConfig();
        _setWithdrawalContract(_withdrawalContract);
    }

    /// @notice Authorization function for UUPS proxy upgrades
    // solhint-disable-next-line no-empty-blocks
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

    function getId(address pa, address ra, uint256 initialArp, uint256 expiry, address exchangeRateProvider)
        external
        pure
        returns (Id)
    {
        return PairLibrary.initalize(pa, ra, initialArp, expiry, exchangeRateProvider).toId();
    }

    function initializeModuleCore(
        address pa,
        address ra,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider
    ) external override {
        onlyConfig();
        if (expiryInterval == 0) {
            revert InvalidExpiry();
        }
        Pair memory key = PairLibrary.initalize(pa, ra, initialArp, expiryInterval, exchangeRateProvider);
        Id id = key.toId();

        State storage state = states[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        IAssetFactory assetsFactory = IAssetFactory(SWAP_ASSET_FACTORY);

        address lv = assetsFactory.deployLv(ra, pa, address(this), initialArp, expiryInterval, exchangeRateProvider);

        PsmLibrary.initialize(state, key);
        VaultLibrary.initialize(state.vault, lv, ra, initialArp);

        emit InitializedModuleCore(id, pa, ra, lv, expiryInterval, initialArp, exchangeRateProvider);
    }

    function issueNewDs(
        Id id,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks,
        uint256 ammLiquidationDeadline
    ) external override {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];

        Pair storage info = state.info;

        // we update the rate, if this is a yield bearing PA then the rate should go up.
        // that's why there's no check that prevents the rate from going up.
        uint256 exchangeRates = PsmLibrary._getLatestRate(state);

        (address ct, address ds) = IAssetFactory(SWAP_ASSET_FACTORY).deploySwapAssets(
            IAssetFactory.DeployParams(
                info.ra,
                state.info.pa,
                address(this),
                info.initialArp,
                info.expiryInterval,
                info.exchangeRateProvider,
                exchangeRates,
                state.globalAssetIdx + 1
            )
        );

        // avoid stack to deep error
        _initOnNewIssuance(id, ct, ds, info.expiryInterval);
        // avoid stack to deep error
        getRouterCore().setDecayDiscountAndRolloverPeriodOnNewIssuance(
            id, decayDiscountRateInDays, rolloverPeriodInblocks
        );
        VaultLibrary.onNewIssuance(
            state, state.globalAssetIdx - 1, getRouterCore(), getAmmRouter(), ammLiquidationDeadline
        );
    }

    function _initOnNewIssuance(Id id, address ct, address ds, uint256 _expiryInterval) internal {
        State storage state = states[id];

        address ra = state.info.ra;
        uint256 prevIdx = state.globalAssetIdx;
        uint256 idx = ++state.globalAssetIdx;

        PsmLibrary.onNewIssuance(state, ct, ds, idx, prevIdx);

        getRouterCore().onNewIssuance(id, idx, ds, ra, ct);

        emit Issued(id, idx, block.timestamp + _expiryInterval, ds, ct, AmmId.unwrap(toAmmId(ra, ct)));
    }

    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updateRepurchaseFeePercentage(state, newRepurchaseFeePercentage);

        emit RepurchaseFeeRateUpdated(id, newRepurchaseFeePercentage);
    }

    /**
     * @notice update pausing status of PSM Deposits
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     */
    function updatePsmDepositsStatus(Id id, bool isPSMDepositPaused) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePsmDepositsStatus(state, isPSMDepositPaused);
        emit PsmDepositsStatusUpdated(id, isPSMDepositPaused);
    }

    /**
     * @notice update pausing status of PSM Withdrawals
     * @param id id of the pair
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     */
    function updatePsmWithdrawalsStatus(Id id, bool isPSMWithdrawalPaused) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePsmWithdrawalsStatus(state, isPSMWithdrawalPaused);
        emit PsmWithdrawalsStatusUpdated(id, isPSMWithdrawalPaused);
    }

    /**
     * @notice update pausing status of PSM Repurchases
     * @param id id of the pair
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     */
    function updatePsmRepurchasesStatus(Id id, bool isPSMRepurchasePaused) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePsmRepurchasesStatus(state, isPSMRepurchasePaused);
        emit PsmRepurchasesStatusUpdated(id, isPSMRepurchasePaused);
    }

    /**
     * @notice update pausing status of LV deposits
     * @param id id of the pair
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     */
    function updateLvDepositsStatus(Id id, bool isLVDepositPaused) external {
        onlyConfig();
        State storage state = states[id];
        VaultLibrary.updateLvDepositsStatus(state, isLVDepositPaused);
        emit LvDepositsStatusUpdated(id, isLVDepositPaused);
    }

    /**
     * @notice update pausing status of LV withdrawals
     * @param id id of the pair
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updateLvWithdrawalsStatus(Id id, bool isLVWithdrawalPaused) external {
        onlyConfig();
        State storage state = states[id];
        VaultLibrary.updateLvWithdrawalsStatus(state, isLVWithdrawalPaused);
        emit LvWithdrawalsStatusUpdated(id, isLVWithdrawalPaused);
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
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePSMBaseRedemptionFeePercentage(state, newPsmBaseRedemptionFeePercentage);
        emit PsmBaseRedemptionFeePercentageUpdated(id, newPsmBaseRedemptionFeePercentage);
    }

    function expiry(Id id) external view override returns (uint256 expiry) {
        expiry = PsmLibrary.nextExpiry(states[id]);
    }
}
