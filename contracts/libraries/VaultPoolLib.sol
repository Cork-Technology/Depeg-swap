// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {VaultPool, VaultWithdrawalPool, VaultAmmLiquidityPool} from "./State.sol";
import {MathHelper} from "./MathHelper.sol";

/**
 * @title VaultPool Library Contract
 * @author Cork Team
 * @notice VaultPool Library implements features related to LV Pools(liquidity Vault Pools)
 */
library VaultPoolLibrary {
    function reserve(VaultPool storage self, uint256 totalLvIssued, uint256 addedRa, uint256 addedPa) internal {
        uint256 totalLvWithdrawn = self.withdrawalPool.atrributedLv;

        // RA
        uint256 totalRa = self.withdrawalPool.raBalance + addedRa;
        (uint256 attributedToWithdraw, uint256 attributedToAmm, uint256 ratePerLv) =
            MathHelper.separateLiquidity(totalRa, totalLvIssued, totalLvWithdrawn);

        self.withdrawalPool.raBalance = attributedToWithdraw;
        self.ammLiquidityPool.balance = attributedToAmm;
        self.withdrawalPool.raExchangeRate = ratePerLv;

        // PA
        uint256 totalPa = self.withdrawalPool.paBalance + addedPa;
        (attributedToWithdraw, attributedToAmm, ratePerLv) =
            MathHelper.separateLiquidity(totalPa, totalLvIssued, totalLvWithdrawn);

        self.withdrawalPool.paBalance = attributedToAmm; 
        self.withdrawalPool.stagnatedPaBalance = attributedToWithdraw;
        self.withdrawalPool.paExchangeRate = ratePerLv;

        assert(totalRa == self.withdrawalPool.raBalance + self.ammLiquidityPool.balance);
        assert(totalPa == self.withdrawalPool.paBalance + self.withdrawalPool.stagnatedPaBalance);
    }

    function rationedToAmm(VaultPool storage self, uint256 ratio) internal view returns (uint256 ra, uint256 ct, uint256 originalBalance) {
        originalBalance = self.ammLiquidityPool.balance;

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(originalBalance, ratio);
        
    }

    function resetAmmPool(VaultPool storage self) internal {
        self.ammLiquidityPool.balance = 0;
    }
}
