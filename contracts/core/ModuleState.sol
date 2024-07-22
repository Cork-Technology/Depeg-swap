// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../libraries/Pair.sol";
import "../libraries/State.sol";
import "../interfaces/IAssetFactory.sol";
import "../interfaces/ICommon.sol";
import "../libraries/PsmLib.sol";

abstract contract ModuleState is ICommon {
    using PsmLibrary for State;

    mapping(Id => State) internal states;
    address _factory;

    function factory() external view returns (address) {
        return _factory;
    }

    constructor(address factoryAddress) {
        _factory = factoryAddress;
    }

    function getFactory() internal view returns (IAssetFactory) {
        return IAssetFactory(_factory);
    }

    modifier onlyInitialized(Id id) {
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
