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
import "./VaultPoolLib.sol";


library VaultLibrary {
    using VaultConfigLibrary for VaultConfig;
    using PairLibrary for Pair;
    using LvAssetLibrary for LvAsset;
    using VaultLibrary for VaultState;
    using PsmLibrary for State;
    using RedemptionAssetManagerLibrary for WrappedAsset;
    using RedemptionAssetManagerLibrary for PsmRedemptionAssetManager;
    using BitMaps for BitMaps.BitMap;
    using VaultLibrary for VaultState;
    using DepegSwapLibrary for DepegSwap;
    using VaultPoolLibrary for VaultPool;

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

    function provideAmmLiquidityFromPool(State storage self) internal {
        uint256 ratio = MathHelper.calculatePriceRatio(
            self.vault.getSqrtPriceX96(),
            MathHelper.DEFAULT_DECIMAL
        );

        (uint256 ra, uint256 ct) = self.vault.pool.rationedToAmm(ratio);

        __addLiquidityToAmmUnchecked(self, ra, ct);
        PsmLibrary.unsafeIssueToLv(self, ct);

        self.vault.pool.resetAmmPool();

        // TODO : actually mint CT and DS
    }

    // FIXME :  temporary, will be updated once we integrate with uniswap
    function __addLiquidityToAmmUnchecked(
        State storage self,
        uint256 ra,
        uint256 ct
    ) internal {
        self.vault.config.lpRaBalance += ra;
        self.vault.config.lpCtBalance += ct;
    }

    function _limitOrderDs(uint256 amount) internal {
        // TODO : placeholder
    }

    function getSqrtPriceX96(
        VaultState storage self
    ) internal view returns (uint160) {
        // TODO : placeholder
        // 1 for now, so that every 1 ra there must be 1 ct
        return 79228162514264337593543950336;
    }

    // MUST be called on every new DS issuance
    function onNewIssuanceAndExpiry(State storage self, uint256 dsId) internal {
        // do nothing at first issuance
        if (dsId == 0) {
            return;
        }

        if (!self.vault.lpLiquidated.get(dsId)) {
            _liquidatedLp(self, dsId);
        }

        provideAmmLiquidityFromPool(self);
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

    function __provideLiquidityWithRatio(
        State storage self,
        uint256 amount
    ) internal returns (uint256 ra, uint256 ct) {
        uint256 ratio = MathHelper.calculatePriceRatio(
            self.vault.getSqrtPriceX96(),
            MathHelper.DEFAULT_DECIMAL
        );

        (ra, ct) = MathHelper.calculateAmounts(amount, ratio);
        __addLiquidityToAmmUnchecked(self, ra, ct);

        PsmLibrary.unsafeIssueToLv(self, ct);

        _limitOrderDs(amount);
    }

    function deposit(
        State storage self,
        address from,
        uint256 amount
    ) internal {
        safeBeforeExpired(self);
        self.vault.balances.ra.lockUnchecked(amount, from);
        __provideLiquidityWithRatio(self, amount);
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
        self.vault.pool.withdrawEligible[owner] += amount;
        self.vault.pool.withdrawalPool.atrributedLv += amount;
        self.vault.lv.lockFrom(amount, owner);
    }

    function lvLockedFor(
        State storage self,
        address owner
    ) internal view returns (uint256) {
        return self.vault.pool.withdrawEligible[owner];
    }

    function cancelRedemptionRequest(
        State storage self,
        address owner,
        uint256 amount
    ) internal {
        safeBeforeExpired(self);
        uint256 userEligible = self.vault.pool.withdrawEligible[owner];

        if (userEligible == 0) {
            revert Unauthorized(msg.sender);
        }

        if (userEligible < amount) {
            revert InsufficientBalance(owner, amount, userEligible);
        }

        self.vault.pool.withdrawEligible[owner] -= amount;
        self.vault.pool.withdrawalPool.atrributedLv -= amount;
        self.vault.lv.unlockTo(amount, owner);
    }

    function transferRedemptionRights(
        State storage self,
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 initialOwneramount = self.vault.pool.withdrawEligible[from];

        if (initialOwneramount == 0) {
            revert Unauthorized(msg.sender);
        }

        if (initialOwneramount < amount) {
            revert InsufficientBalance(from, amount, initialOwneramount);
        }

        self.vault.pool.withdrawEligible[to] += amount;
        self.vault.pool.withdrawEligible[from] -= amount;
    }

    function _liquidatedLp(State storage self, uint256 dsId) internal {
        // TODO : placeholder
        // the following things should happen here(taken directly from the whitepaper) :
        // 1. The AMM LP is redeemed to receive CT + RA
        // 2. Any excess DS in the LV is paired with CT to redeem RA
        // 3. The excess CT is used to claim RA + PA in the PSM
        // 4. End state: Only RA + redeemed PA remains

        self.vault.lpLiquidated.set(dsId);
        // IMPORTANT : for now, we only unlock the wa to ourself
        // since we don't have the AMM LP yet
        // since the ds isn't sold right now so it's safe to do this
        // but that means we won't receive any pegged asset from the PSM yet
        // since the number of CT and DS in LV will always be the same
        // due to not having an actual AMM.
        uint256 ammCtBalance = self.vault.config.lpCtBalance;
        uint256 totalRa = self.vault.config.lpRaBalance + ammCtBalance;
        PsmLibrary.lvRedeemRaWithCtDs(self, ammCtBalance, dsId);

        // static values for PA for now.
        uint256 ctAttributedToPa = 0;
        uint256 pa = PsmLibrary.lvRedeemRaPaWithCt(self, ctAttributedToPa);

        self.vault.pool.reserve(self.vault.lv.totalIssued(), totalRa, pa);

        self.vault.config.lpRaBalance = 0;
        self.vault.config.lpCtBalance = 0;
    }

    function reservedForWithdrawal(
        State storage self
    ) internal view returns (uint256 ra, uint256 pa) {
        ra = self.vault.pool.withdrawalPool.raBalance;
        pa = self.vault.pool.withdrawalPool.paBalance;
    }

    // FIXME : maybe remove this when the off-chain aggregator is finalized
    function _tryLiquidateLp(
        State storage self
    )
        internal
        view
        returns (
            VaultWithdrawalPool memory withdrawalPool,
            VaultAmmLiquidityPool memory ammLiquidityPool
        )
    {
        // due to not having an actual AMM.
        uint256 ammCtBalance = self.vault.config.lpCtBalance;
        uint256 totalRa = self.vault.config.lpRaBalance + ammCtBalance;

        withdrawalPool = self.vault.pool.withdrawalPool;
        ammLiquidityPool = self.vault.pool.ammLiquidityPool;

        // static values for PA for now.
        uint256 ctAttributedToPa = 0;
        VaultPoolLibrary.tryReserve(
            withdrawalPool,
            ammLiquidityPool,
            self.vault.lv.totalIssued(),
            totalRa,
            ctAttributedToPa
        );
    }

    function redeemExpired(
        State storage self,
        address owner,
        address receiver,
        uint256 amount
    ) internal returns (uint256 attributedRa, uint256 attributedPa) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        uint256 userEligible = self.vault.pool.withdrawEligible[owner];

        if (userEligible == 0 && !ds.isExpired()) {
            revert Unauthorized(owner);
        }

        // user can only redeem up to the amount they requested, when there's a DS active
        // if there's no DS active, then there's no cap on the amount of LV that can be redeemed
        if (!ds.isExpired() && userEligible < amount) {
            revert InsufficientBalance(owner, amount, userEligible);
        }

        if (ds.isExpired() && !self.vault.lpLiquidated.get(dsId)) {
            _liquidatedLp(self, dsId);
            assert(self.vault.balances.ra.locked == 0);
        }

        ERC20Burnable lv = ERC20Burnable(self.vault.lv._address);

        uint256 burnUserAmount;
        uint256 burnSelfAmount;
        (attributedRa, attributedPa, burnUserAmount, burnSelfAmount) = self
            .vault
            .pool
            .redeem(amount, owner);

        //ra
        IERC20(self.info.pair1).transfer(receiver, attributedRa);
        //pa
        IERC20(self.info.pair0).transfer(receiver, attributedPa);

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
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        uint256 userEligible = self.vault.pool.withdrawEligible[owner];

        if (userEligible == 0 && !ds.isExpired()) {
            revert Unauthorized(owner);
        }

        // user can only redeem up to the amount they requested, when there's a DS active
        // if there's no DS active, then there's no cap on the amount of LV that can be redeemed
        if (!ds.isExpired() && userEligible < amount) {
            revert InsufficientBalance(owner, amount, userEligible);
        }

        VaultWithdrawalPool memory withdrawalPool = self
            .vault
            .pool
            .withdrawalPool;

        VaultAmmLiquidityPool memory ammLiquidityPool = self
            .vault
            .pool
            .ammLiquidityPool;

        if (ds.isExpired() && !self.vault.lpLiquidated.get(dsId)) {
            (withdrawalPool, ammLiquidityPool) = _tryLiquidateLp(self);
            assert(self.vault.balances.ra.locked == 0);
        }

        (attributedRa, attributedPa, approvedAmount) = VaultPoolLibrary
            .tryRedeem(
                self.vault.pool.withdrawEligible,
                withdrawalPool,
                ammLiquidityPool,
                amount,
                owner
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
        uint256 dsId = self.globalAssetIdx;

        feePrecentage = self.vault.config.fee;

        // again, it's safe to do this because there's the same amount of CT + DS in the LV so we treat CT the same as RA
        uint256 totalRa = self.vault.config.lpRaBalance +
            self.vault.config.lpCtBalance;

        console.log("totalRa", totalRa);

        received = MathHelper.calculateEarlyLvRate(
            totalRa,
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

        // TODO : change this into pool function
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

        uint256 totalRa = self.vault.config.lpRaBalance +
            self.vault.config.lpCtBalance;

        received = MathHelper.calculateEarlyLvRate(
            totalRa,
            IERC20(self.vault.lv._address).totalSupply(),
            amount
        );

        fee = MathHelper.calculatePrecentageFee(
            received,
            self.vault.config.fee
        );

        received = received - fee;
    }

    // IMPORTANT : only psm can call this function
    function provideLiquidityWithPsmRepurchase(
        State storage self,
        uint256 amount
    ) internal {
        __provideLiquidityWithRatio(self, amount);
    }

    function sellExcessCt(State storage self) internal {
        // TODO : placeholder
    }

    function createWaPairings(State storage self) internal {
        // TODO : placeholder
    }
}
