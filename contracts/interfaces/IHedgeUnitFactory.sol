// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IErrors} from "./IErrors.sol";

interface IHedgeUnitFactory is IErrors {
    // Event emitted when a new HedgeUnit contract is deployed
    event HedgeUnitDeployed(Id indexed pairId, address pa, address ra, address indexed hedgeUnitAddress);
}
