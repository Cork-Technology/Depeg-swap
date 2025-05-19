// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VaultPool} from "./State.sol";
import {MathHelper} from "./MathHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VaultPool Library Contract
 * @author Cork Team
 * @notice VaultPool Library implements features related to LV Pools(liquidity Vault Pools)
 */
library VaultPoolLibrary {
    function reserve(VaultPool storage self, uint256 totalLvIssued, uint256 addedRa, uint256 addedPa) internal {
        // new protocol amendement, no need to reserve for lv
        uint256 totalLvWithdrawn = 0;

        // RA
        uint256 totalRa = self.withdrawalPool.raBalance + addedRa;

        self.ammLiquidityPool.balance = totalRa;

        // PA
        uint256 totalPa = self.withdrawalPool.paBalance + addedPa;

        self.withdrawalPool.paBalance = totalPa;

        assert(totalRa == self.withdrawalPool.raBalance + self.ammLiquidityPool.balance);
    }

    function rationedToAmm(VaultPool storage self, uint256 ratio, uint8 raDecimals)
        internal
        view
        returns (uint256 ra, uint256 ct, uint256 originalBalance)
    {
        originalBalance = self.ammLiquidityPool.balance;

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(originalBalance, ratio, raDecimals);
    }

    function resetAmmPool(VaultPool storage self) internal {
        self.ammLiquidityPool.balance = 0;
    }
}
