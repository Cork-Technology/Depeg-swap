// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {State} from "./State.sol";
import {DepegSwap} from "./DepegSwapLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

library VaultBalanceLibrary {
    function subtractLpBalance(State storage self, uint256 amount) internal {
        self.vault.balances.lpBalance -= amount;
    }

    function addLpBalance(State storage self, uint256 amount) internal {
        self.vault.balances.lpBalance += amount;
    }

    function lpBalance(State storage self) internal view returns (uint256) {
        return self.vault.balances.lpBalance;
    }
}
