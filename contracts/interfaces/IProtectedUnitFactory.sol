// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IErrors} from "./IErrors.sol";

interface IProtectedUnitFactory is IErrors {
    // Event emitted when a new ProtectedUnit contract is deployed
    event ProtectedUnitDeployed(Id indexed pairId, address pa, address ra, address indexed protectedUnitAddress);
}
