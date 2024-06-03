// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VaultConfig.sol";
import "./PairKey.sol";
import "./LvAssetLib.sol";
import "./PSMLib.sol";
import "./WrappedAssetLib.sol";
import "./MathHelper.sol";
import "./Guard.sol";

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
        // placeholder
    }

    function _limitOrderDs(uint256 amount) internal {
        // placeholder
    }

    function getSqrtPriceX96(
        VaultState storage self
    ) internal view returns (uint160) {
        // placeholder
        return 0;
    }

    /// @notice issue a new pair of DS, will fail if the previous DS isn't yet expired
    function issueNewLv(
        State storage self,
        address lv,
        uint256 idx,
        uint256 prevIdx
    ) internal {
        if (prevIdx != 0) {
            LvAsset storage _lv = self.vault.lv[prevIdx];
            Guard.safeAfterExpired(_lv);
        }

        // to prevent 0 index
        self.globalAssetIdx++;
        idx = self.globalAssetIdx;

        self.vault.lv[idx] = LvAssetLibrary.initialize(lv);
    }

    function safeBeforeExpired(
        State storage self
    ) internal view returns (LvAsset storage lv, uint256 lvId) {
        lvId = self.globalAssetIdx;
        lv = self.vault.lv[lvId];
        Guard.safeBeforeExpired(lv);
    }

    function safeAfterExpired(
        State storage self
    ) internal view returns (LvAsset storage lv, uint256 lvId) {
        lvId = self.globalAssetIdx;
        lv = self.vault.lv[lvId];
        Guard.safeAfterExpired(lv);
    }

    // TODO : check for initialization
    function deposit(
        State storage self,
        address from,
        uint256 amount
    ) internal returns (uint256) {
        (LvAsset storage lv, uint256 lvId) = safeBeforeExpired(self);

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
        lv.issue(from, amount);

        return lvId;
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

    function redeemExpired(State storage self) internal {
        safeAfterExpired(self);
        // TODO calculate LV
    }

    function redeemEarly(uint256 amount) internal {
        // placeholder
    }
}
