// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VaultConfig.sol";
import "./PairKey.sol";
import "./LvAssetLib.sol";
import "./PSMLib.sol";
import "./WrappedAssetLib.sol";
import "./MathHelper.sol";
import "./Guard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

library VaultLibrary {
    using VaultConfigLibrary for VaultConfig;
    using PairKeyLibrary for PairKey;
    using LvAssetLibrary for LvAsset;
    using VaultLibrary for VaultState;
    using PSMLibrary for State;
    using WrappedAssetLibrary for WrappedAsset;
    using VaultLibrary for VaultState;

    function initialize(
        VaultState storage self,
        uint256 fee,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold
    ) internal {
        self.config = VaultConfigLibrary.initialize(
            fee,
            ammWaDepositThreshold,
            ammCtDepositThreshold
        );
    }

    function provideAmmLiquidity(
        VaultState storage self,
        uint256 amountWa,
        uint256 amountCt
    ) internal {
        // TODO : placeholder
    }

    function _limitOrderDs(uint256 amount) internal {
        // TODO : placeholder
    }

    function getSqrtPriceX96(
        VaultState storage self
    ) internal view returns (uint160) {
        // TODO : placeholder
        return 0;
    }

    function safeBeforeExpired(State storage self) internal view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
    }

    function safeAfterExpired(State storage self) internal view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);
    }

    // TODO : check for initialization
    function deposit(
        State storage self,
        address from,
        uint256 amount
    ) internal {
        safeBeforeExpired(self);

        uint256 ratio = MathHelper.calculatePriceRatio(
            self.vault.getSqrtPriceX96(),
            MathHelper.DEFAULT_DECIMAL
        );
        (
            uint256 amountWa,
            uint256 amountCt,
            uint256 leftoverWa,
            uint256 leftoverCt
        ) = MathHelper.calculateAmounts(amount, ratio);

        self.vault.config.increaseWaBalance(leftoverWa);
        self.vault.config.increaseCtBalance(leftoverCt);

        if (self.vault.config.mustProvideLiquidity()) {
            self.vault.provideAmmLiquidity(amountWa, amountCt);
        }

        _limitOrderDs(amount);
        self.vault.lv.issue(from, amount);
    }

    // preview a deposit action with current exchange rate,
    // returns the amount of shares(share pool token) that user will receive
    function previewDeposit(
        uint256 amount
    ) internal pure returns (uint256 lvReceived) {
        lvReceived = amount;
    }

    function requestRedemption(State storage self, address owner) internal {
        safeBeforeExpired(self);
        self.vault.withdrawEligible[owner] = true;
    }

    function _liquidatedLp(
        State storage self
    ) internal returns (uint256 wa, uint256 ct) {
        // TODO : placeholder
        // the following things should happen here(taken directly from the whitepaper) :
        // 1. The AMM LP is redeemed to receive CT + WA
        // 2. Any excess DS in the LV is paired with CT to mint WA
        // 3. The excess CT is used to claim RA + PA as described above
        // 4. All of the above WA get collected in a WA container, the WA is used to redeem RA
        // 5. End state: Only RA + redeemed PA remains

        self.vault.lpLiquidated = true;
        wa = 0;
        ct = 0;
    }

    function redeemExpired(
        State storage self,
        address owner,
        address receiver,
        uint256 amount
    ) internal {
        safeAfterExpired(self);

        if (!self.vault.lpLiquidated) {
            _liquidatedLp(self);
        }

        IERC20 ra = IERC20(self.info._redemptionAsset);
        IERC20 pa = IERC20(self.info._peggedAsset);
        ERC20Burnable lv = ERC20Burnable(self.vault.lv._address);

        uint256 accruedRa = ra.balanceOf(address(this));
        uint256 accruedPa = pa.balanceOf(address(this));
        uint256 totalLv = lv.balanceOf(address(this));

        (uint256 attributedRa, uint256 attributedPa) = MathHelper
            .calculateBaseWithdrawal(totalLv, accruedRa, accruedPa, amount);

        ra.transfer(receiver, attributedRa);
        pa.transfer(receiver, attributedPa);
        lv.burnFrom(owner, amount);
    }

    function redeemEarly(uint256 amount) internal {
        // placeholder
    }
}
