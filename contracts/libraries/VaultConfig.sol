// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ICommon} from "../interfaces/ICommon.sol";
import {VaultConfig} from "./State.sol";

/**
 * @title VaultConfig Library Contract
 * @author Cork Team
 * @notice VaultConfig Library implements features related to LV(liquidity Vault) Config
 */
library VaultConfigLibrary {
    /**
     *   This denotes maximum fee allowed in contract
     *   Here 1 ether = 1e18 so maximum 5% fee allowed
     */
    uint256 internal constant MAX_ALLOWED_FEES = 5 ether;

    function initialize(uint256 fee) internal pure returns (VaultConfig memory) {
        if (fee > MAX_ALLOWED_FEES) {
            revert ICommon.InvalidFees();
        }
        return VaultConfig({fee: fee, lpBalance: 0, isDepositPaused: false, isWithdrawalPaused: false});
    }

    function updateFee(VaultConfig storage self, uint256 fee) internal {
        if (fee > MAX_ALLOWED_FEES) {
            revert ICommon.InvalidFees();
        }
        self.fee = fee;
    }
}
