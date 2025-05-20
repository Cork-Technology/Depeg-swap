// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ICorkHook} from "./../interfaces/UniV4/IMinimalHook.sol";
import {State} from "./State.sol";
import {DepegSwap} from "./DepegSwapLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

library VaultBalanceLibrary {
    // should only be called after depositing & removing liquidity from the amm
    // this opens up inflation-attack opportunity, so we should partially solve them by having slippage protection and minimum LV cap
    function sync(State storage self, ICorkHook hook) internal {
        address ra = self.info.ra;
        address ct = self.ds[self.globalAssetIdx].ct;

        // means that it's not yet initialized if it's error, which can only happen if the vault
        // sync itself just after new issuance after removing liquidity from the old market
        // in that case, the info on the state storage would be updated and it'll point to the new(not yet created) market
        // so it errors,  we then reset the lp balance3
        try hook.getLiquidityToken(ra, ct) returns (address lpToken) {
            uint256 balance = IERC20(lpToken).balanceOf(address(this));

            self.vault.balances.lpBalance = balance;
        } catch {
            self.vault.balances.lpBalance = 0;
        }
    }

    function lpBalance(State storage self) internal view returns (uint256) {
        return self.vault.balances.lpBalance;
    }
}
