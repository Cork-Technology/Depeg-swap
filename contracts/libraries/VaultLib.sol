// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VaultConfig.sol";
import "./Pair.sol";
import "./LvAssetLib.sol";
import "./PsmLib.sol";
import "./WrappedAssetLib.sol";
import "./MathHelper.sol";
import "./Guard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

library VaultLibrary {
    using VaultConfigLibrary for VaultConfig;
    using PairLibrary for Pair;
    using LvAssetLibrary for LvAsset;
    using VaultLibrary for VaultState;
    using PsmLibrary for State;
    using WrappedAssetLibrary for WrappedAsset;
    using WrappedAssetLibrary for WrappedAssetInfo;

    using VaultLibrary for VaultState;

    /// @notice caller is not authorized to perform the action, e.g transfering
    /// redemption rights to another address while not having the rights
    error Unauthorized(address caller);

    // TODO : integrate this
    function initialize(
        VaultState storage self,
        address lv,
        uint256 fee,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold
    ) internal {
        self.config = VaultConfigLibrary.initialize(
            fee,
            ammWaDepositThreshold,
            ammCtDepositThreshold
        );

        self.lv = LvAsset(lv);
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
        // 4 for now, so that every 4 wa there must be 1 ct
        return 158456325028528675187087900672;
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
        self.vault.balances.wa.lockFrom(amount, from);

        uint256 ratio = MathHelper.calculatePriceRatio(
            self.vault.getSqrtPriceX96(),
            MathHelper.DEFAULT_DECIMAL
        );
        (uint256 wa, uint256 ct) = MathHelper.calculateAmounts(amount, ratio);

        if (self.vault.config.mustProvideLiquidity()) {
            self.vault.provideAmmLiquidity(wa, ct);
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

    // TODO : test this
    function transferRedemptionRights(
        State storage self,
        address from,
        address to
    ) internal {
        safeBeforeExpired(self);

        if (!self.vault.withdrawEligible[from]) {
            revert Unauthorized(msg.sender);
        }

        self.vault.withdrawEligible[from] = false;
        self.vault.withdrawEligible[to] = true;
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

        if (!self.vault.withdrawEligible[owner]) {
            revert Unauthorized(owner);
        }

        if (!self.vault.lpLiquidated) {
            _liquidatedLp(self);
        }

        IERC20 ra = IERC20(self.info.pair1);
        IERC20 pa = IERC20(self.info.pair0);
        ERC20Burnable lv = ERC20Burnable(self.vault.lv._address);

        uint256 accruedRa = ra.balanceOf(address(this));
        uint256 accruedPa = pa.balanceOf(address(this));
        uint256 totalLv = lv.balanceOf(address(this));

        (uint256 attributedRa, uint256 attributedPa) = MathHelper
            .calculateBaseWithdrawal(totalLv, accruedRa, accruedPa, amount);

        self.vault.balances.raBalance -= attributedRa;
        self.vault.balances.paBalance -= attributedPa;

        ra.transfer(receiver, attributedRa);
        pa.transfer(receiver, attributedPa);
        lv.burnFrom(owner, amount);
    }

    // taken directly from spec document, technically below is what should happen in this function
    //
    // '#' refers to the total circulation supply of that token.
    // '&' refers to the total amount of token in the LV.
    //
    // say our percent fee is 3%
    // fee(amount)
    //
    // say the amount of user LV token is 'N'
    //
    // AMM LP liquidation (#LP/#LV) provide more CT($CT) + WA($WA) :
    // &CT = &CT + $CT
    // &WA = &WA + $WA
    //
    // Create WA pairing CT with DS inside the vault :
    // &WA = &WA + &(CT + DS)
    //
    // Excess and unpaired CT is sold to AMM to provide WA($WA) :
    // &WA = $WA
    //
    // the LV token rate is :
    // eLV = &WA/#LV
    //
    // redemption amount(rA) :
    // rA = N x eLV
    //
    // final amount(Fa) :
    // Fa = rA - fee(rA)
    function redeemEarly(
        State storage self,
        address owner,
        address receiver,
        uint256 amount
    ) internal {
        safeBeforeExpired(self);
        _liquidatedLp(self);
        createWaPairings(self);

        uint256 received = MathHelper.calculateEarlyLvRate(
            self.vault.config.freeWaBalance,
            IERC20(self.vault.lv._address).totalSupply(),
            amount
        );

        received =
            received -
            MathHelper.calculatePrecentageFee(received, self.vault.config.fee);

        self.vault.config.freeWaBalance -= received;

        ERC20Burnable(self.vault.lv._address).burnFrom(owner, amount);
        self.vault.balances.wa.unlockTo(received, receiver);
    }

    function sellExcessCt(State storage self) internal {
        // TODO : placeholder
    }

    function createWaPairings(State storage self) internal {
        // TODO : placeholder
    }
}
