// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/dev/IPsmDev.sol";
import "./Dev.sol";
import "../ModuleState.sol";
import "../libraries/VaultLib.sol";
import "../libraries/State.sol";

abstract contract PsmDev is ModuleState, IPsmDev {
    using VaultLibrary for *;

    function psmIncreaseCtBalance(
        address ct,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ct).mint(address(this), amount);
        states[id].psmBalances.ctBalance += amount;
    }

    function psmDecreaseCtBalance(
        address ct,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ct).burnSelf(amount);
        states[id].psmBalances.ctBalance -= amount;
    }

    function psmIncreaseDsBalance(
        address ds,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ds).mint(address(this), amount);
        states[id].psmBalances.dsBalance += amount;
    }

    function psmDecreaseDsBalance(
        address ds,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ds).burnSelf(amount);
        states[id].psmBalances.dsBalance -= amount;
    }

    function psmIncreasePaBalance(uint256 amount, Id id) external override {
        address pa = states[id].info.pair1;

        IDevToken(pa).mint(address(this), amount);
        states[id].psmBalances.paBalance += amount;
    }

    function psmDecreasePaBalance(uint256 amount, Id id) external override {
        address pa = states[id].info.pair1;
        IDevToken(pa).burnSelf(amount);
        states[id].psmBalances.paBalance -= amount;
    }

    function psmIncreaseRaBalance(uint256 amount, Id id) external override {
        address ra = states[id].info.pair0;

        IDevToken(ra).mint(address(this), amount);
        states[id].psmBalances.ra.free += amount;
    }

    function psmDecreaseRaBalance(uint256 amount, Id id) external override {
        address ra = states[id].info.pair0;

        IDevToken(ra).burnSelf(amount);
        states[id].psmBalances.ra.free -= amount;
    }
}
