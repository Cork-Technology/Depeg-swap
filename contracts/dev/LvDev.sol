// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/dev/ILvDev.sol";
import "./Dev.sol";
import "../ModuleState.sol";
import "../libraries/VaultLib.sol";
import "../libraries/WrappedAssetLib.sol";
import "../libraries/State.sol";

abstract contract LvDev is ModuleState, ILvDev {
    using VaultLibrary for *;
    using WrappedAssetLibrary for WrappedAssetInfo;

    function lvIncreaseCtBalance(
        address ct,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ct).mint(address(this), amount);
        states[id].vault.balances.ctBalance += amount;
    }

    function lvDecreaseCtBalance(
        address ct,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ct).burnSelf(amount);
        states[id].vault.balances.ctBalance -= amount;
    }

    function lvIncreaseDsBalance(
        address ds,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ds).mint(address(this), amount);
        states[id].vault.balances.dsBalance += amount;
    }

    function lvDecreaseDsBalance(
        address ds,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(ds).burnSelf(amount);
        states[id].vault.balances.dsBalance -= amount;
    }

    function lvIncreasePaBalance(uint256 amount, Id id) external override {
        address pa = states[id].info.pair1;
        IDevToken(pa).mint(address(this), amount);
        states[id].vault.balances.paBalance += amount;
    }

    function lvDecreasePaBalance(uint256 amount, Id id) external override {
        address pa = states[id].info.pair1;
        IDevToken(pa).burnSelf(amount);
        states[id].vault.balances.paBalance -= amount;
    }

    function lvIncreaseRaBalance(uint256 amount, Id id) external override {
        address ra = states[id].info.pair0;

        IDevToken(ra).mint(address(this), amount);
        states[id].vault.balances.raBalance += amount;
    }

    function lvDecreaseRaBalance(uint256 amount, Id id) external override {
        address ra = states[id].info.pair0;
        IDevToken(ra).burnSelf(amount);
        states[id].vault.balances.raBalance -= amount;
    }

    function lvIncreaseFreeWaBalance(uint256 amount, Id id) external override {
        address ra = states[id].info.pair0;

        IDevToken(ra).mint(address(this), amount);
        states[id].vault.balances.raBalance += amount;
        
        IDevToken(wa).mint(address(this), amount);
        states[id].vault.balances.raBalance += amount;
    }

    function lvDecreaseFreeWaBalance(
        address wa,
        uint256 amount,
        Id id
    ) external override {
        IDevToken(wa).burnSelf(amount);
        states[id].vault.balances.raBalance -= amount;
    }
}
