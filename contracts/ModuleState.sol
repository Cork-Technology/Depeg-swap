// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./libraries/PairKey.sol";
import "./libraries/State.sol";
import "./interfaces/IAssetFactory.sol";
import "./interfaces/ICommon.sol";
import "./libraries/PsmLib.sol";

abstract contract ModuleState is ICommon {
    using PsmLibrary for State;

    mapping(ModuleId => State) internal states;
    address _factory;

    constructor(address factory) {
        _factory = factory;
    }

    function getFactory() internal view returns (IAssetFactory) {
        return IAssetFactory(_factory);
    }

    modifier onlyInitialized(ModuleId id) {
        if (!states[id].isInitialized()) {
            revert Uinitialized();
        }
        _;
    }

    function _onlyValidAsset(address asset) internal view {
        if (getFactory().isDeployed(asset) == false) {
            revert InvalidAsset(asset);
        }
    }
}
