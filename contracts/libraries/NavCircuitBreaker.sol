// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {State, NavCircuitBreaker} from "./State.sol";
import {IVault} from "./../interfaces/IVault.sol";
import {MathHelper} from "./MathHelper.sol";
import {IErrors} from "./../interfaces/IErrors.sol";

library NavCircuitBreakerLibrary {
    function _oldestSnapshotIndex(NavCircuitBreaker storage self) private view returns (uint256) {
        return self.lastUpdate0 <= self.lastUpdate1 ? 0 : 1;
    }

    function _updateSnapshot(NavCircuitBreaker storage self, uint256 currentNav) internal returns (bool) {
        uint256 oldestIndex = _oldestSnapshotIndex(self);

        if (oldestIndex == 0) {
            if (block.timestamp < self.lastUpdate0 + 1 days) return false;

            self.snapshot0 = currentNav;
            self.lastUpdate0 = block.timestamp;

            emit IVault.SnapshotUpdated(oldestIndex, currentNav);
        } else {
            if (block.timestamp < self.lastUpdate1 + 1 days) return false;

            self.snapshot1 = currentNav;
            self.lastUpdate1 = block.timestamp;

            emit IVault.SnapshotUpdated(oldestIndex, currentNav);
        }

        return true;
    }

    function _getReferenceNav(NavCircuitBreaker storage self) private view returns (uint256) {
        return self.snapshot0 > self.snapshot1 ? self.snapshot0 : self.snapshot1;
    }

    function validateAndUpdateDeposit(NavCircuitBreaker storage self, uint256 currentNav) internal {
        _updateSnapshot(self, currentNav);
        uint256 referenceNav = _getReferenceNav(self);
        uint256 delta = MathHelper.calculatePercentageFee(self.navThreshold, referenceNav);

        if (currentNav < delta) {
            revert IErrors.NavBelowThreshold(referenceNav, delta, currentNav);
        }
    }

    function updateOnWithdrawal(NavCircuitBreaker storage self, uint256 currentNav) internal returns (bool) {
        return _updateSnapshot(self, currentNav);
    }

    function forceUpdateSnapshot(NavCircuitBreaker storage self, uint256 currentNav) internal returns (bool) {
        return _updateSnapshot(self, currentNav);
    }
}
