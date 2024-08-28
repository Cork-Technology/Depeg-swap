pragma solidity 0.8.24;

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
        self.withdrawalPool.atrributedLv = totalLvWithdrawn;

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

        self.withdrawalPool.paBalance = attributedToWithdraw;
        self.withdrawalPool.stagnatedPaBalance = attributedToWithdraw;
        self.withdrawalPool.paExchangeRate = ratePerLv;

        assert(totalRa == self.withdrawalPool.raBalance + self.ammLiquidityPool.balance);
    }

    function tryReserve(
        VaultWithdrawalPool memory withdrawalPool,
        VaultAmmLiquidityPool memory ammLiquidityPool,
        uint256 totalLvIssued,
        uint256 addedRa,
        uint256 addedPa
    ) internal pure {
        uint256 totalLvWithdrawn = withdrawalPool.atrributedLv;
        withdrawalPool.atrributedLv = totalLvWithdrawn;

        // RA
        uint256 totalRa = withdrawalPool.raBalance + addedRa;
        (uint256 attributedToWithdraw, uint256 attributedToAmm, uint256 ratePerLv) =
            MathHelper.separateLiquidity(totalRa, totalLvIssued, totalLvWithdrawn);

        withdrawalPool.raBalance = attributedToWithdraw;
        ammLiquidityPool.balance = attributedToAmm;
        withdrawalPool.raExchangeRate = ratePerLv;

        // PA
        uint256 totalPa = withdrawalPool.paBalance + addedPa;
        (attributedToWithdraw, attributedToAmm, ratePerLv) =
            MathHelper.separateLiquidity(totalPa, totalLvIssued, totalLvWithdrawn);

        withdrawalPool.paBalance = attributedToWithdraw;
        withdrawalPool.stagnatedPaBalance = attributedToWithdraw;
        withdrawalPool.paExchangeRate = ratePerLv;

        assert(totalRa == withdrawalPool.raBalance + ammLiquidityPool.balance);
    }

    function __decreaseUserAttributed(VaultPool storage self, uint256 amount, address owner) internal {
        self.withdrawEligible[owner] -= amount;
    }

    function redeem(VaultPool storage self, uint256 amount, address owner)
        internal
        returns (uint256 ra, uint256 pa, uint256 excess, uint256 attributed)
    {
        uint256 userEligible = self.withdrawEligible[owner];

        if (userEligible >= amount) {
            attributed = amount;

            (ra, pa) = __redeemfromWithdrawalPool(self, amount);
            __decreaseUserAttributed(self, amount, owner);
        } else {
            attributed = userEligible;
            excess = amount - userEligible;

            assert(excess + attributed == amount);

            (ra, pa) = __redeemExcessFromAmmPool(self, userEligible, excess);
            __decreaseUserAttributed(self, userEligible, owner);
        }
    }

    function tryRedeem(
        mapping(address => uint256) storage withdrawEligible,
        VaultWithdrawalPool memory withdrawalPool,
        VaultAmmLiquidityPool memory ammLiquidityPool,
        uint256 amount,
        address owner
    ) internal view returns (uint256 ra, uint256 pa, uint256 excess) {
        uint256 userEligible = withdrawEligible[owner];

        if (userEligible >= amount) {
            ra = MathHelper.calculateRedeemAmountWithExchangeRate(amount, withdrawalPool.raExchangeRate);

            pa = MathHelper.calculateRedeemAmountWithExchangeRate(amount, withdrawalPool.paExchangeRate);
        } else {
            uint256 attributed = userEligible;
            excess = amount - userEligible;

            assert(excess + attributed == amount);

            ra = MathHelper.calculateRedeemAmountWithExchangeRate(attributed, withdrawalPool.raExchangeRate);

            pa = MathHelper.calculateRedeemAmountWithExchangeRate(attributed, withdrawalPool.paExchangeRate);

            uint256 withdrawnFromAmm =
                MathHelper.calculateRedeemAmountWithExchangeRate(excess, withdrawalPool.raExchangeRate);

            ra += withdrawnFromAmm;

            ammLiquidityPool.balance -= withdrawnFromAmm;
        }
    }

    function __redeemfromWithdrawalPool(VaultPool storage self, uint256 amount)
        internal
        returns (uint256 ra, uint256 pa)
    {
        self.withdrawalPool.atrributedLv -= amount;
        (ra, pa) = __tryRedeemfromWithdrawalPool(self, amount);

        self.withdrawalPool.raBalance -= ra;
        self.withdrawalPool.paBalance -= pa;
    }

    function __tryRedeemfromWithdrawalPool(VaultPool storage self, uint256 amount)
        internal
        view
        returns (uint256 ra, uint256 pa)
    {
        ra = MathHelper.calculateRedeemAmountWithExchangeRate(amount, self.withdrawalPool.raExchangeRate);

        pa = MathHelper.calculateRedeemAmountWithExchangeRate(amount, self.withdrawalPool.paExchangeRate);
    }

    function __tryRedeemExcessFromAmmPool(VaultPool storage self, uint256 amountAttributed, uint256 excessAmount)
        internal
        view
        returns (uint256 ra, uint256 pa, uint256 withdrawnFromAmm)
    {
        (ra, pa) = __tryRedeemfromWithdrawalPool(self, amountAttributed);

        withdrawnFromAmm =
            MathHelper.calculateRedeemAmountWithExchangeRate(excessAmount, self.withdrawalPool.raExchangeRate);

        ra += withdrawnFromAmm;
    }

    function __redeemExcessFromAmmPool(VaultPool storage self, uint256 amountAttributed, uint256 excessAmount)
        internal
        returns (uint256 ra, uint256 pa)
    {
        uint256 withdrawnFromAmm;
        (ra, pa, withdrawnFromAmm) = __tryRedeemExcessFromAmmPool(self, amountAttributed, excessAmount);

        self.ammLiquidityPool.balance -= withdrawnFromAmm;
    }

    function rationedToAmm(VaultPool storage self, uint256 ratio) internal view returns (uint256 ra, uint256 ct) {
        uint256 amount = self.ammLiquidityPool.balance;

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amount, ratio);
    }

    function resetAmmPool(VaultPool storage self) internal {
        self.ammLiquidityPool.balance = 0;
    }
}
