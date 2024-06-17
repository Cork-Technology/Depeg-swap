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

    function initialize(
        VaultState storage self,
        address lv,
        uint256 fee,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold,
        address wa
    ) internal {
        self.config = VaultConfigLibrary.initialize(
            fee,
            ammWaDepositThreshold,
            ammCtDepositThreshold
        );

        self.lv = LvAsset(lv);
        self.balances.wa = WrappedAssetLibrary.initialize(wa);
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

    function deposit(
        State storage self,
        address from,
        uint256 amount
    ) internal {
        safeBeforeExpired(self);
        self.vault.balances.wa.lockUnchecked(amount, from);

        uint256 ratio = MathHelper.calculatePriceRatio(
            self.vault.getSqrtPriceX96(),
            MathHelper.DEFAULT_DECIMAL
        );

        (uint256 wa, uint256 ct) = MathHelper.calculateAmounts(amount, ratio);
        self.vault.config.lpWaBalance += wa;
        self.vault.config.lpCtBalance += ct;

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

    function transferRedemptionRights(
        State storage self,
        address from,
        address to
    ) internal {
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

    function _unwrapAllWaToSelf(State storage self) internal {
        // IMPORTANT : for now, we only unlock the wa to ourself
        // since we don't have the AMM LP yet
        // since the ds isn't sold right now so it's safe to do this
        uint256 total = self.vault.config.lpWaBalance +
            self.vault.config.lpCtBalance;
        self.vault.balances.raBalance += total;

        self.vault.balances.wa.unlockToUnchecked(total, address(this));
    }

    function redeemExpired(
        State storage self,
        address owner,
        address receiver,
        uint256 amount
    ) internal returns (uint256 attributedRa, uint256 attributedPa) {
        safeAfterExpired(self);

        if (!self.vault.withdrawEligible[owner]) {
            revert Unauthorized(owner);
        }

        if (!self.vault.lpLiquidated) {
            _liquidatedLp(self);
            _unwrapAllWaToSelf(self);
            assert(self.vault.balances.wa.locked == 0);
        }

        ERC20Burnable lv = ERC20Burnable(self.vault.lv._address);

        uint256 accruedRa = self.vault.balances.raBalance;
        uint256 accruedPa = self.vault.balances.paBalance;
        uint256 totalLv = lv.totalSupply();

        (attributedRa, attributedPa) = MathHelper.calculateBaseWithdrawal(
            totalLv,
            accruedRa,
            accruedPa,
            amount
        );

        self.vault.balances.raBalance -= attributedRa;
        self.vault.balances.paBalance -= attributedPa;

        IERC20 ra = IERC20(self.info.pair1);
        IERC20 pa = IERC20(self.info.pair0);

        ra.transfer(receiver, attributedRa);
        pa.transfer(receiver, attributedPa);

        lv.burnFrom(owner, amount);
    }

    function previewRedeemExpired(
        State storage self,
        uint256 amount
    ) internal view returns (uint256 attributedRa, uint256 attributedPa) {
        ERC20Burnable lv = ERC20Burnable(self.vault.lv._address);

        uint256 accruedRa = self.vault.balances.raBalance;
        uint256 accruedPa = self.vault.balances.paBalance;
        uint256 totalLv = lv.totalSupply();
        
        (attributedRa, attributedPa) = MathHelper.calculateBaseWithdrawal(
            totalLv,
            accruedRa,
            accruedPa,
            amount
        );
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
    ) internal returns (uint256 received, uint256 fee, uint256 feePrecentage) {
        safeBeforeExpired(self);
        _liquidatedLp(self);
        createWaPairings(self);

        feePrecentage = self.vault.config.fee;

        uint256 totalWa = self.vault.config.lpWaBalance +
            self.vault.config.lpCtBalance;

        received = MathHelper.calculateEarlyLvRate(
            totalWa,
            IERC20(self.vault.lv._address).totalSupply(),
            amount
        );

        uint256 ratio = MathHelper.calculatePriceRatio(
            self.vault.getSqrtPriceX96(),
            MathHelper.DEFAULT_DECIMAL
        );

        // calculate substracted LP liquidity in respect to the price ratio
        // this is done to minimize price impact
        (uint256 wa, uint256 ct) = MathHelper.calculateAmounts(received, ratio);
        self.vault.config.lpWaBalance -= wa;
        self.vault.config.lpCtBalance -= ct;

        fee = MathHelper.calculatePrecentageFee(
            received,
            self.vault.config.fee
        );
        self.vault.config.accmulatedFee += fee;
        received = received - fee;

        // IMPORTANT: ideally, the source of the WA that's used to fulfill
        // early redemption should be calculated in a way that respect the
        // current price ratio of the asset in the AMM and then an algorithm should
        // decide how much LP WA is used, how much CT is paired with existing DS in the LV
        // to turned into WA for user redemption, it should look like this :
        //
        // if the price ratio is 2:1, then for every 2 WA, there should be 1 CT
        // assuming the DS is not sold yet, then it should use ~66% of WA and ~33% of CT to be paired with DS
        // for user withdrawal
        //
        // but for now, as we don't currently have a good general grip on AMM mechanics,
        // we calculate the rate in as if all the CT can be readyily paired with DS and turned into WA, but we
        // but we source everything from the LP WA which will most likely has a worse side effect on price than the ideal one.
        // you could say we currently use the "dumb" algorithm for now.
        //

        ERC20Burnable(self.vault.lv._address).burnFrom(owner, amount);
        self.vault.balances.wa.unlockToUnchecked(received, receiver);
        returnLpFunds(self);
    }

    function previewRedeemEarly(
        State storage self,
        uint256 amount
    )
        internal
        view
        returns (uint256 received, uint256 fee, uint256 feePrecentage)
    {
        safeBeforeExpired(self);

        feePrecentage = self.vault.config.fee;

        uint256 totalWa = self.vault.config.lpWaBalance +
            self.vault.config.lpCtBalance;

        received = MathHelper.calculateEarlyLvRate(
            totalWa,
            IERC20(self.vault.lv._address).totalSupply(),
            amount
        );

        fee = MathHelper.calculatePrecentageFee(
            received,
            self.vault.config.fee
        );

        received = received - fee;
    }

    function returnLpFunds(State storage self) internal {
        self.vault.lpLiquidated = false;
        // TODO : placeholder
    }

    function sellExcessCt(State storage self) internal {
        // TODO : placeholder
    }

    function createWaPairings(State storage self) internal {
        // TODO : placeholder
    }
}