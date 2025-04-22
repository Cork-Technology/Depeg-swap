// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ERC7575PsmAdapter} from "./adapters/ERC7575PsmAdapter.sol";
import {ERC7575ReservesAdapter} from "./adapters/ERC7575ReservesAdapter.sol";
import {Asset as CorkToken} from "../core/assets/Asset.sol";
import {ModuleCore} from "../core/ModuleCore.sol";
import {Id} from "../libraries/Pair.sol";
import {IErrors} from "../interfaces/IErrors.sol";

enum AdapterType { NONE, RESERVES, PSM }

struct AdapterParams {
    AdapterType typ;
    address share;
    address asset;
}

/**
 * @title Factory contract for Cork assets adapter
 * @author Cork Team
 * @notice Factory contract for deploying Cork Asset adapters
 */
contract CorkShareAdapterFactory is OwnableUpgradeable, UUPSUpgradeable, IErrors {
    address public moduleCore;
    address public ammHook;

    mapping(address => AdapterParams) public adapters;

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the factory contract
     * @param _owner The owner of the factory contract
     */
    function initialize(address _owner, address _moduleCore, address _ammHook) external initializer {
        if (_owner == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        moduleCore = _moduleCore;
        ammHook = _ammHook;
    }

    /**
     * @notice Upgrades the implementation of the factory contract
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Whether an adapter was created with the factory.
    function isCorkAdapter(address target) external view returns (bool) {
        return adapters[target].typ != AdapterType.NONE;
    }

    function _storeAndEmit(address adapter, AdapterParams memory params) internal {
        adapters[adapter] = params;

        emit CorkAdapterCreated(adapter, params.typ, params.share);
    }

    /**
     * @inheritdoc ICorkAdapterFactory
     */
    function createERC7575ReservesAdapters(
        address _share,
        address[] calldata _assets,
    ) external returns (ERC7575ReservesAdapter[] memory _adapters) {
        _adapters = new ERC7575ReservesAdapter[](_assets.length);

        for (uint256 i = 0; i < _assets.length; ++i) {
            ERC7575ReservesAdapter adapter = new ERC7575ReservesAdapter(_share, _assets[i]);
            _adapters[i] = adapter;

            _storeAndEmit(
                address(adapter),
                AdapterParams({
                    typ: AdapterType.RESERVES,
                    share: _share,
                    asset: assets[i],
                })
            );
        }
    }

    /**
     * @inheritdoc ICorkAdapterFactory
     */
    function createERC7575PsmAdapters(
        address _share,
        address[] calldata _assets,
        Id _marketId,
    ) external returns (ERC7575PsmAdapter[] memory _adapters) {
        _adapters = new ERC7575PsmAdapter[](_assets.length);

        uint256 ctEpoch = CorkToken(_share).dsId();
        (address coverToken,) = moduleCore.swapAsset(_marketId, ctEpoch);
        if (_share != coverToken) revert InvalidToken();

        for (uint256 i = 0; i < _assets.length; ++i) {
            ERC7575PsmAdapter adapter = new ERC7575PsmAdapter(_share, _assets[i], _marketId, moduleCore);
            _adapters[i] = adapter;

            _storeAndEmit(
                address(adapter),
                AdapterParams({
                    typ: AdapterType.PSM,
                    share: _share,
                    asset: assets[i],
                })
            );
        }
    }