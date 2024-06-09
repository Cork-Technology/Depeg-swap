// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../../libraries/Pair.sol";

// - increases & decrease CT balance
// - increases & decrease DS balance
// - make deposit(the user who execute this will be minted RA and automatically deposit it into the psm, similar to PSM, it acts kinda like a router)
// - increase & decrease PA balance
// - increase & decrease RA balance
// - increase & decrease locked WA balance (will automatically mint RA, wrap it to WA and deposit to psm, will NOT mint CT + DS to user)
interface IPsmDev {
    function psmIncreaseCtBalance(address ct, uint256 amount, Id id) external;

    function psmDecreaseCtBalance(address ct, uint256 amount, Id id) external;

    function psmIncreaseDsBalance(address ds, uint256 amount, Id id) external;

    function psmDecreaseDsBalance(address ds, uint256 amount, Id id) external;

    function psmIncreasePaBalance(address pa, uint256 amount, Id id) external;

    function psmDecreasePaBalance(address pa, uint256 amount, Id id) external;

    function psmIncreaseRaBalance(address ra, uint256 amount, Id id) external;

    function psmDecreaseRaBalance(address ra, uint256 amount, Id id) external;

    function psmIncreaselockedWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external;

    function psmDecreaselockedWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external;
}
