// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC7575PsmAdapter} from "./ERC7575PsmAdapter.sol";
import {ERC7575ReservesAdapter} from "./ERC7575ReservesAdapter.sol";
import {Asset as CorkToken} from "../core/assets/Asset.sol";
import {ModuleCore} from "../core/ModuleCore.sol";
import {Id} from "../libraries/Pair.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {ICorkAdapterFactory} from "../interfaces/adapters/ICorkAdapterFactory.sol";

/**
 * @title Factory contract for Cork assets adapter
 * @author Cork Team
 * @notice Factory contract for deploying Cork Asset adapters
 */
contract CorkAdapterFactory is OwnableUpgradeable, UUPSUpgradeable, IErrors, ICorkAdapterFactory {
    ModuleCore public moduleCore;
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
     * @param ownerAdd The owner of the factory contract
     * @param moduleCoreAdd The address of the module core contract
     * @param ammHookAdd The address of the AMM hook contract
     */
    function initialize(address ownerAdd, address moduleCoreAdd, address ammHookAdd) external initializer {
        if (ownerAdd == address(0) || moduleCoreAdd == address(0) || ammHookAdd == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init(ownerAdd);
        __UUPSUpgradeable_init();

        moduleCore = ModuleCore(moduleCoreAdd);
        ammHook = ammHookAdd;
    }

    /**
     * @notice Upgrades the implementation of the factory contract
     * @param newImplementation The address of the new implementation contract
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Whether an adapter was created with the factory.
    /// @param target The address of the adapter.
    /// @return isCorkAdapter Whether the adapter was created with the CorkAdapterFactory.
    function isCorkAdapter(address target) external view returns (bool isCorkAdapter) {
        isCorkAdapter = adapters[target].adapterType != AdapterType.NONE;
    }

    /// @notice Stores and emits an adapter.
    /// @param adapter The address of the adapter.
    /// @param params The parameters of the adapter.
    function _storeAndEmit(address adapter, AdapterParams memory params) internal {
        adapters[adapter] = params;

        emit CorkAdapterCreated(adapter, params.adapterType, params.share);
    }

    /// @notice Creates a new ERC7575ReservesAdapter.
    /// @param share The address of the share token.
    /// @param assets The addresses of the assets.
    /// @return adapters The new ERC7575ReservesAdapters.
    function createERC7575ReservesAdapters(address share, address[] calldata assets)
        external
        returns (ERC7575ReservesAdapter[] memory adapters)
    {
        adapters = new ERC7575ReservesAdapter[](assets.length);

        uint256 length = assets.length;
        for (uint256 i = 0; i < length; ++i) {
            ERC7575ReservesAdapter adapter = new ERC7575ReservesAdapter(IUniswapV2Pair(share), assets[i]);
            adapters[i] = adapter;

            _storeAndEmit(
                address(adapter), AdapterParams({adapterType: AdapterType.RESERVES, share: share, asset: assets[i]})
            );
        }
    }

    /// @notice Creates a new ERC7575PsmAdapter.
    /// @param share The address of the share token.
    /// @param assets The addresses of the assets.
    /// @param marketId The market ID.
    /// @return adapters The new ERC7575PsmAdapters.
    function createERC7575PsmAdapters(address share, address[] calldata assets, Id marketId)
        external
        returns (ERC7575PsmAdapter[] memory adapters)
    {
        adapters = new ERC7575PsmAdapter[](assets.length);

        uint256 ctEpoch = CorkToken(share).dsId();
        (address coverToken,) = moduleCore.swapAsset(marketId, ctEpoch);
        if (share != coverToken) revert InvalidToken();

        uint256 length = assets.length;
        for (uint256 i = 0; i < length; ++i) {
            ERC7575PsmAdapter adapter = new ERC7575PsmAdapter(CorkToken(share), assets[i], marketId, moduleCore);
            adapters[i] = adapter;

            _storeAndEmit(
                address(adapter), AdapterParams({adapterType: AdapterType.PSM, share: share, asset: assets[i]})
            );
        }
    }
}
