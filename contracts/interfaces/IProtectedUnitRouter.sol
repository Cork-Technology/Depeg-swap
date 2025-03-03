// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

interface IProtectedUnitRouter is IErrors {
    struct BatchMintParams {
        uint256 deadline;
        address[] protectedUnits;
        uint256[] amounts;
        bytes[] rawDsPermitSigs;
        bytes[] rawPaPermitSigs;
    }

    struct BatchBurnPermitParams {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        bytes rawProtectedUnitPermitSig;
    }

    event ProtectedUnitSet(address protectedUnit);

    event ProtectedUnitRemoved(address protectedUnit);
}
