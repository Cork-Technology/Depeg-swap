// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VaultConfig.sol";
import "./PairKey.sol";
import "./LvAssetLib.sol";
import "./PSMLib.sol";
import "./WrappedAssetLib.sol";
import "./MathHelper.sol";

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
        address lvAsset,
        uint256 fee,
        uint256 waConvertThreshold,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold
    ) internal {
        self.lv = LvAsset({_address: lvAsset});
        self.config = VaultConfigLibrary.initialize(
            fee,
            waConvertThreshold,
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

    function deposit(
        State storage self,
        address from,
        uint256 amount
    ) internal {
        uint256 ratio = MathHelper.calculatePriceRatio(self.vault.getSqrtPriceX96());
        (
            uint256 amountWa,
            uint256 amountCt,
            uint256 leftoverWa,
            uint256 leftoverCt
        ) = MathHelper.calculateAmounts(amount, ratio);

        self.vault.config.increaseWaBalance(leftoverWa);
        self.vault.config.increaseCtBalance(leftoverCt);

        self.vault.provideAmmLiquidity(amountWa, amountCt);
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

    function requestWithdrawal(State storage self) internal {
        // placeholder
    }

    function withdrawExpired() internal {
        // placeholder
    }

    function withdrawEarly(uint256 amount) internal {
        // placeholder
    }
}
