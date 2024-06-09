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
        states[id].psmBalances.raBalance += amount;
    }

    function psmDecreaseRaBalance(uint256 amount, Id id) external override {
        address ra = states[id].info.pair0;

        IDevToken(ra).burnSelf(amount);
        states[id].psmBalances.raBalance -= amount;
    }

    function psmIncreaselockedWaBalance(
        uint256 amount,
        Id id
    ) external override {
        State storage self = states[id];
        address ra = self.info.pair0;
        IDevToken(ra).mint(address(this), amount);
        
        // mint RA, wrap it to WA and deposit to psm
        self.psmBalances.wa.locked += amount;
        WrappedAssetLibrary.approveAndWrap(
            self.psmBalances.wa._address,
            amount
        );
    }

    function psmDecreaselockedWaBalance(
        uint256 amount,
        Id id
    ) external override {
        State storage self = states[id];

        WrappedAssetLibrary.unlockTo(
            self.psmBalances.wa,
            amount,
            address(0)
        );
    }
}
