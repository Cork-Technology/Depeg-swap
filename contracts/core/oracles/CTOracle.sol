// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {BaseOracle} from "./BaseOracle.sol";
import {Id} from "./../../libraries/Pair.sol";
import {Asset} from "./../assets/Asset.sol";
import {ModuleCore} from "./../ModuleCore.sol";

contract CtOracle is BaseOracle {
    /// @dev will fail right here if the ct is a legacy asset since legacy CT doesn't have marketId function
    constructor(address _moduleCore, address _ct) BaseOracle(_moduleCore, _ct, Asset(_ct).marketId()) {}

    function _prepareRoundData() internal view override returns (uint256 backedRa, uint256 backedPa) {
        (backedRa, backedPa) = ct.getReserves();
    }
}
