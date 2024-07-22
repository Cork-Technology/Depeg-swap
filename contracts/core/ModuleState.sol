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
    address swapAssetFactory;
    /// @dev in this case is uni v2
    address ammFactory;

    function factory() external view returns (address) {
        return swapAssetFactory;
    }

    constructor(address _swapAssetFactory, address _ammFactory) {
        swapAssetFactory = _swapAssetFactory;
        ammFactory = _ammFactory;
    }

    function getSwapAssetFactory() internal view returns (IAssetFactory) {
        return IAssetFactory(swapAssetFactory);
    }

    modifier onlyInitialized(Id id) {
        if (!states[id].isInitialized()) {
            revert Uinitialized();
        }
        _;
    }

    function _onlyValidAsset(address asset) internal view {
        if (getSwapAssetFactory().isDeployed(asset) == false) {
            revert InvalidAsset(asset);
        }
    }
}
