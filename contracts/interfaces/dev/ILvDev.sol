// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../../libraries/Pair.sol";

// - increases & decrease CT balance
// - increases & decrease DS balance
// - make deposit(the user who execute this will be minted RA and automatically deposit it into the LV, similar to PSM, it acts kinda like a router)
// - increase & decrease PA balance
// - increase & decrease RA balance
// - increase & decrease free WA balance (will automatically mint RA, wrap it to WA and deposit to LV, will NOT mint CT + DS to user)
interface ILvDev {
    function lvIncreaseCtBalance(address ct, uint256 amount, Id id) external;

    function lvDecreaseCtBalance(address ct, uint256 amount, Id id) external;

    function lvIncreaseDsBalance(address ds, uint256 amount, Id id) external;

    function lvDecreaseDsBalance(address ds, uint256 amount, Id id) external;

    function lvIncreasePaBalance(address pa, uint256 amount, Id id) external;

    function lvDecreasePaBalance(address pa, uint256 amount, Id id) external;

    function lvIncreaseRaBalance(address ra, uint256 amount, Id id) external;

    function lvDecreaseRaBalance(address ra, uint256 amount, Id id) external;

    function lvIncreaseFreeWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external;

    function lvDecreaseFreeWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external;
}
