// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MathHelper} from "../libraries/MathHelper.sol";
import {DsFlashSwaplibrary} from "../libraries/DsFlashSwap.sol";
import {SwapperMathLibrary} from "../libraries/DsSwapperMathLib.sol";
import {VaultLibrary} from "../libraries/VaultLib.sol";
import {PsmLibrary} from "../libraries/PsmLib.sol";

contract Libraries {
    using MathHelper for *;
    using DsFlashSwaplibrary for *;
    using SwapperMathLibrary for *;
    using PsmLibrary for *;
    using VaultLibrary for *;

    constructor() {}
}
