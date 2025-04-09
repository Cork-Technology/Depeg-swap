// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {BaseOracle} from "./BaseOracle.sol";
import {Id} from "./../../libraries/Pair.sol";
import {ModuleCore} from "./../ModuleCore.sol";

contract LegacyCtOracle is BaseOracle {
    constructor(address _moduleCore, address _ct, Id _marketId) BaseOracle(_moduleCore, _ct, _marketId) {}

    function _prepareRoundData() internal view override returns (uint256 backedRa, uint256 backedPa) {
        uint256 marketEpoch = moduleCore.lastDsId(marketId);

        uint256 ctEpoch = ct.dsId();

        if (marketEpoch == ctEpoch) {
            backedRa = moduleCore.valueLocked(marketId, true);
            backedPa = moduleCore.valueLocked(marketId, false);
        } else {
            backedRa = moduleCore.valueLocked(marketId, ctEpoch, true);
            backedPa = moduleCore.valueLocked(marketId, ctEpoch, false);
        }
    }
}
