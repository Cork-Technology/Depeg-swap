// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

interface IHedgeUnitRouter is IErrors {
    struct BatchMintParams {
        uint256 deadline;
        address[] hedgeUnits;
        uint256[] amounts;
        bytes[] rawDsPermitSigs;
        bytes[] rawPaPermitSigs;
    }

    struct BatchBurnPermitParams {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        bytes rawHedgeUnitPermitSig;
    }

    event HedgeUnitSet(address hedgeUnit);

    event HedgeUnitRemoved(address hedgeUnit);
}
