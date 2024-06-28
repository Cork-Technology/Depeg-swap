// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VaultConfig.sol";
import "./Pair.sol";
import "./LvAssetLib.sol";
import "./PsmLib.sol";
import "./RedemptionAssetManagerLib.sol";
import "./MathHelper.sol";
import "./Guard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

library VaultLibrary {
    using VaultConfigLibrary for VaultConfig;
    using PairLibrary for Pair;
    using LvAssetLibrary for LvAsset;
    using VaultLibrary for VaultState;
    using PsmLibrary for State;
    using RedemptionAssetManagerLibrary for WrappedAsset;
    using RedemptionAssetManagerLibrary for RedemptionAssetManager;
    using BitMaps for BitMaps.BitMap;
    using VaultLibrary for VaultState;
    using DepegSwapLibrary for DepegSwap;

    /// @notice caller is not authorized to perform the action, e.g transfering
    /// redemption rights to another address while not having the rights
    error Unauthorized(address caller);

    /// @notice inssuficient balance to perform expiry redeem(e.g requesting 5 LV to redeem but trying to redeem 10)
    error InsufficientBalance(
        address caller,
        uint256 requested,
        uint256 balance
    );

    function initialize(
        VaultState storage self,
        address lv,
        uint256 fee,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold,
        address ra
    ) internal {
        self.config = VaultConfigLibrary.initialize(
            fee,
            ammWaDepositThreshold,
            ammCtDepositThreshold
        );

        self.lv = LvAssetLibrary.initialize(lv);
        self.balances.ra = RedemptionAssetManagerLibrary.initialize(ra);
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
        // 4 for now, so that every 4 ra there must be 1 ct
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
        self.vault.balances.ra.lockUnchecked(amount, from);

        uint256 ratio = MathHelper.calculatePriceRatio(
            self.vault.getSqrtPriceX96(),
            MathHelper.DEFAULT_DECIMAL
        );

        (uint256 ra, uint256 ct) = MathHelper.calculateAmounts(amount, ratio);
        self.vault.config.lpRaBalance += ra;
        self.vault.config.lpCtBalance += ct;

        if (self.vault.config.mustProvideLiquidity()) {
            self.vault.provideAmmLiquidity(ra, ct);
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

    function requestRedemption(
        State storage self,
        address owner,
        uint256 amount
    ) internal {
        safeBeforeExpired(self);
        self.vault.withdrawEligible[owner] += amount;
        self.vault.lv.lockFrom(amount, owner);
    }

    function lvLockedFor(
        State storage self,
        address owner
    ) internal view returns (uint256) {
        return self.vault.withdrawEligible[owner];
    }

    function cancelRedemptionRequest(
        State storage self,
        address owner,
        uint256 amount
    ) internal {
        safeBeforeExpired(self);
        uint256 userEligible = self.vault.withdrawEligible[owner];

        if (userEligible == 0) {
            revert Unauthorized(msg.sender);
        }

        if (userEligible < amount) {
            revert InsufficientBalance(owner, amount, userEligible);
        }

        self.vault.withdrawEligible[owner] -= amount;
        self.vault.lv.unlockTo(amount, owner);
    }

    function transferRedemptionRights(
        State storage self,
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 initialOwneramount = self.vault.withdrawEligible[from];

        if (initialOwneramount == 0) {
            revert Unauthorized(msg.sender);
        }

        if (initialOwneramount < amount) {
            revert InsufficientBalance(from, amount, initialOwneramount);
        }

        self.vault.withdrawEligible[to] += initialOwneramount;
        self.vault.withdrawEligible[from] -= amount;
    }

    function _liquidatedLp(
        State storage self,
        uint256 dsId
    ) internal returns (uint256 wa, uint256 ct) {
        // TODO : placeholder
        // the following things should happen here(taken directly from the whitepaper) :
        // 1. The AMM LP is redeemed to receive CT + WA
        // 2. Any excess DS in the LV is paired with CT to mint WA
        // 3. The excess CT is used to claim RA + PA as described above
        // 4. All of the above WA get collected in a WA container, the WA is used to redeem RA
        // 5. End state: Only RA + redeemed PA remains

        self.vault.lpLiquidated.set(dsId);

        wa = 0;
        ct = 0;
    }

    function _____tempTransferAllLpRaToSelf(State storage self) internal {
        // IMPORTANT : for now, we only unlock the wa to ourself
        // since we don't have the AMM LP yet
        // since the ds isn't sold right now so it's safe to do this
        uint256 total = self.vault.config.lpRaBalance +
            self.vault.config.lpCtBalance;

        self.vault.balances.ra.incFree(total);

        self.vault.config.lpRaBalance = 0;
        self.vault.config.lpCtBalance = 0;
    }

    function redeemExpired(
        State storage self,
        address owner,
        address receiver,
        uint256 amount
    ) internal returns (uint256 attributedRa, uint256 attributedPa) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        uint256 userEligible = self.vault.withdrawEligible[owner];

        if (userEligible == 0 && !ds.isExpired()) {
            revert Unauthorized(owner);
        }

        // user can only redeem up to the amount they requested, when there's a DS active
        // if there's no DS active, then there's no cap on the amount of LV that can be redeemed
        if (!ds.isExpired() && userEligible < amount) {
            revert InsufficientBalance(owner, amount, userEligible);
        }

        // we set the user eligible to 0, since the user has redeemed more LV than requested
        // else we just subtract the amount from the user eligible
        if (userEligible <= amount) {
            self.vault.withdrawEligible[owner] = 0;
        } else {
            self.vault.withdrawEligible[owner] -= amount;
        }

        if (ds.isExpired() && !self.vault.lpLiquidated.get(dsId)) {
            _liquidatedLp(self, dsId);
            // FIXME : this will be changed after LV AMM integration with potentially bucketizing redeem amount
            _____tempTransferAllLpRaToSelf(self);
            assert(self.vault.balances.ra.locked == 0);
        }

        ERC20Burnable lv = ERC20Burnable(self.vault.lv._address);

        (attributedRa, attributedPa) = MathHelper.calculateBaseWithdrawal(
            lv.totalSupply(),
            self.vault.balances.ra.free,
            self.vault.balances.paBalance,
            amount
        );

        self.vault.balances.ra.free -= attributedRa;
        self.vault.balances.paBalance -= attributedPa;

        //ra
        IERC20(self.info.pair1).transfer(receiver, attributedRa);
        //pa
        IERC20(self.info.pair0).transfer(receiver, attributedPa);

        // we need to burn the LV token that's redeemed, if the user withdraw without a cap
        // then we also need to burn the remaining user LV token that's not locked in the LV
        uint256 burnSelfAmount = userEligible;
        // we only need to burn user LV when the user redeem more LV than requested
        uint256 burnUserAmount;

        if (userEligible < amount) {
            burnUserAmount = amount - userEligible;
        }

        assert(burnSelfAmount + burnUserAmount == amount);

        self.vault.lv.burnSelf(burnSelfAmount);

        if (burnUserAmount != 0) {
            lv.burnFrom(owner, burnUserAmount);
        }
    }

    function previewRedeemExpired(
        State storage self,
        uint256 amount,
        address owner
    )
        internal
        view
        returns (
            uint256 attributedRa,
            uint256 attributedPa,
            uint256 approvedAmount
        )
    {
        ERC20Burnable lv = ERC20Burnable(self.vault.lv._address);

        uint256 accruedRa = self.vault.balances.ra.free;
        uint256 accruedPa = self.vault.balances.paBalance;
        uint256 totalLv = lv.totalSupply();

        (attributedRa, attributedPa) = MathHelper.calculateBaseWithdrawal(
            totalLv,
            accruedRa,
            accruedPa,
            amount
        );

        uint256 userEligible = self.vault.withdrawEligible[owner];

        // we need to burn the LV token that's redeemed, if the user withdraw without a cap
        // then we also need to burn the remaining user LV token that's not locked in the LV
        uint256 burnSelfAmount = userEligible;
        // we only need to burn user LV when the user redeem more LV than requested

        if (userEligible < amount) {
            approvedAmount = amount - userEligible;
        }

        assert(burnSelfAmount + approvedAmount == amount);
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
        uint256 dsId = self.globalAssetIdx;

        _liquidatedLp(self, dsId);
        createWaPairings(self);

        feePrecentage = self.vault.config.fee;

        uint256 totalWa = self.vault.config.lpRaBalance +
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
        (uint256 ra, uint256 ct) = MathHelper.calculateAmounts(received, ratio);
        self.vault.config.lpRaBalance -= ra;
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
        self.vault.balances.ra.unlockToUnchecked(received, receiver);
        returnLpFunds(self, dsId);
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

        uint256 totalWa = self.vault.config.lpRaBalance +
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

    function returnLpFunds(State storage self, uint256 dsId) internal {
        self.vault.lpLiquidated.unset(dsId);
        // TODO : placeholder
    }

    function sellExcessCt(State storage self) internal {
        // TODO : placeholder
    }

    function createWaPairings(State storage self) internal {
        // TODO : placeholder
    }
}