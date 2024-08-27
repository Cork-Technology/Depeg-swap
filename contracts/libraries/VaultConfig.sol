// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ICommon} from "../interfaces/ICommon.sol";
import {VaultConfig} from "./State.sol";

library VaultConfigLibrary {
    function initialize(uint256 fee) internal pure returns (VaultConfig memory) {
        if (fee > 5 ether) {
            revert ICommon.InvalidFees();
        }
        return VaultConfig({
            fee: fee,
            lpRaBalance: 0,
            lpCtBalance: 0,
            lpBalance: 0,
            isDepositPaused: false,
            isWithdrawalPaused: false
        });
    }

    function updateFee(VaultConfig storage self, uint256 fee) internal {
        if (fee > 5 ether) {
            revert ICommon.InvalidFees();
        }
        self.fee = fee;
    }
}
