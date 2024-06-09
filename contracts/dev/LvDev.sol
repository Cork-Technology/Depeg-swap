// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/dev/ILvDev.sol";
import "./Dev.sol";
import "../ModuleState.sol";

abstract contract LvDev is ModuleState, ILvDev {
    function lvIncreaseCtBalance(
        address ct,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ct).mint(address(this), amount);
        states[id].
    }

    function lvDecreaseCtBalance(
        address ct,
        uint256 amount,
        Id id
    ) external override;

    function lvIncreaseDsBalance(
        address ds,
        uint256 amount,
        Id id
    ) external override;

    function lvDecreaseDsBalance(
        address ds,
        uint256 amount,
        Id id
    ) external override;

    function lvDdepositDev(address wa, uint256 amount, Id id) external override;

    function lvIncreasePaBalance(
        address pa,
        uint256 amount,
        Id id
    ) external override;

    function lvDecreasePaBalance(
        address pa,
        uint256 amount,
        Id id
    ) external override;

    function lvIncreaseRaBalance(
        address ra,
        uint256 amount,
        Id id
    ) external override;

    function lvDecreaseRaBalance(
        address ra,
        uint256 amount,
        Id id
    ) external override;

    function lvIncreaseFreeWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external override;

    function lvDecreaseFreeWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external override;
}
