// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {State} from "./State.sol";
import {DepegSwap} from "./DepegSwapLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

library VaultBalanceLibrary {
    function syncLpBalance(State storage self, ICorkHook ammRouter, uint256 dsId) internal {
        DepegSwap storage ds = self.ds[dsId];
        syncLpBalance(self, ammRouter, ds.ct);
    }

    function syncLpBalance(State storage self, ICorkHook ammRouter, address ct) internal {
        // the only case where this fails is when the AMM is not yet initialized,
        // an edge case where this would happen is when a user would deposit a very small amount
        // of RA at initialization(e.g 1), before the AMM is initialized.
        // in that case it's safe to reset the lp balance back to 0
        try ammRouter.getLiquidityToken(self.info.ra, ct) returns (address _lpToken) {
            IERC20 lpToken = IERC20(_lpToken);
            self.vault.balances.lpBalance = lpToken.balanceOf(address(this));
        } catch {
            self.vault.balances.lpBalance = 0;
        }
    }

    function lpBalance(State storage self) internal view returns (uint256) {
        return self.vault.balances.lpBalance;
    }
}
