// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/dev/IPsmDev.sol";
import "./Dev.sol";
import "../ModuleState.sol";
import "../libraries/VaultLib.sol";
import "../libraries/WrappedAssetLib.sol";
import "../libraries/State.sol";

abstract contract LvDev is ModuleState, IPsmDev {
    using VaultLibrary for *;
    using WrappedAssetLibrary for WrappedAssetInfo;

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

    function psmIncreasePaBalance(
        address pa,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(pa).mint(address(this), amount);
        states[id].psmBalances.paBalance += amount;
    }

    function psmDecreasePaBalance(
        address pa,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(pa).burnSelf(amount);
        states[id].psmBalances.paBalance -= amount;
    }

    function psmIncreaseRaBalance(
        address ra,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ra).mint(address(this), amount);
        states[id].psmBalances.raBalance += amount;
    }

    function psmDecreaseRaBalance(
        address ra,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ra).burnSelf(amount);
        states[id].psmBalances.raBalance -= amount;
    }

    function psmIncreaselockedWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external override {
        State storage self = states[id];
        self.psmBalances.wa;
        self.psmBalances.wa.locked += amount;
        self.waInfo.mint(amount);
    }

    function psmDecreaselockedWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external override;
}
