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
    address public factoryAddress;
    address public configAddress;

    /** @dev checks if caller is config contract or not
     */
    modifier onlyConfig() {
        if (msg.sender != configAddress) {
            revert OnlyConfigAllowed();
        }
        _;
    }

    constructor(address _factory, address _config) {
        factoryAddress = _factory;
        configAddress = _config;
    }

    function getFactory() internal view returns (IAssetFactory) {
        return IAssetFactory(factoryAddress);
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
