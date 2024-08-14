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
import "./uni-v2/UniswapV2Library.sol";
import "../interfaces/IDsFlashSwapRouter.sol";
import "../interfaces/IDsFlashSwapRouter.sol";
import "../interfaces/uniswap-v2/RouterV2.sol";

library VaultLibrary {
    using VaultConfigLibrary for VaultConfig;
    using PairLibrary for Pair;
    using LvAssetLibrary for LvAsset;
    using PsmLibrary for State;
    using RedemptionAssetManagerLibrary for PsmRedemptionAssetManager;
    using BitMaps for BitMaps.BitMap;
    using DepegSwapLibrary for DepegSwap;
    using VaultPoolLibrary for VaultPool;

    // TODO : for now a static ratio deposit value used to provide liquidity for the first time, this should be changed later
    /// @notice this will set the initial CT price to 0.9 RA, thus also making the initial price of DS to be 0.1 RA
    uint256 constant DEFAULT_AMM_DEPOSIT_RATIO = 9e17;

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
    ) external {
        self.config = VaultConfigLibrary.initialize(
            fee,
            ammWaDepositThreshold,
            ammCtDepositThreshold
        );

        self.lv = LvAssetLibrary.initialize(lv);
        self.balances.ra = RedemptionAssetManagerLibrary.initialize(ra);
    }

    function __addLiquidityToAmmUnchecked(
        State storage self,
        uint256 raAmount,
        uint256 ctAmount,
        address raAddress,
        address ctAddress,
        IUniswapV2Router02 ammRouter
    ) internal {
        (uint256 raTolerance, uint256 ctTolerance) = MathHelper
            .calculateWithTolerance(
                raAmount,
                ctAmount,
                MathHelper.UNIV2_STATIC_TOLERANCE
            );

        ERC20(raAddress).approve(address(ammRouter), raAmount);
        ERC20(ctAddress).approve(address(ammRouter), ctAmount);

        (
            address token0,
            address token1,
            uint256 token0Amount,
            uint256 token1Amount
        ) = MinimalUniswapV2Library.sortTokensUnsafeWithAmount(
                raAddress,
                ctAddress,
                raAmount,
                ctAmount
            );
        (, , uint256 token0Tolerance, uint256 token1Tolerance) = MinimalUniswapV2Library
            .sortTokensUnsafeWithAmount(
                raAddress,
                ctAddress,
                raTolerance,
                ctTolerance
            );

        // TODO : what do we do if there's leftover deposit due to the tolerance level? for now will just ignore it.
        (, , uint256 lp) = ammRouter.addLiquidity(
            token0,
            token1,
            token0Amount,
            token1Amount,
            token0Tolerance,
            token1Tolerance,
            address(this),
            block.timestamp
        );

        self.vault.config.lpBalance += lp;
    }

    function _addFlashSwapReserve(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        DepegSwap storage ds,
        uint256 amount
    ) internal {
        Asset(ds._address).approve(address(flashSwapRouter), amount);
        flashSwapRouter.addReserve(
            self.info.toId(),
            self.globalAssetIdx,
            amount
        );
    }

    // MUST be called on every new DS issuance
    function onNewIssuance(
        State storage self,
        uint256 prevDsId,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter
    ) external {
        // do nothing at first issuance
        if (prevDsId == 0) {
            return;
        }

        if (!self.vault.lpLiquidated.get(prevDsId)) {
            _liquidatedLp(self, prevDsId, ammRouter, flashSwapRouter);
        }

        __provideAmmLiquidityFromPool(
            self,
            flashSwapRouter,
            self.ds[self.globalAssetIdx].ct,
            ammRouter
        );
    }

    function safeBeforeExpired(State storage self) internal view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
    }

    function safeAfterExpired(State storage self) external view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);
    }

    function __provideLiquidityWithRatio(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        IUniswapV2Router02 ammRouter
    ) internal returns (uint256 ra, uint256 ct) {
        uint256 dsId = self.globalAssetIdx;

        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(
            amount,
            ctRatio
        );

        __provideLiquidity(
            self,
            ra,
            ct,
            flashSwapRouter,
            ctAddress,
            ammRouter,
            dsId
        );
    }

    function __getAmmCtPriceRatio(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        uint256 dsId
    ) internal view returns (uint256 ratio) {
        // This basically means that if the reserve is empty, then we use the default ratio
        ratio = DEFAULT_AMM_DEPOSIT_RATIO;

        try
            // will always fail for the first deposit
            flashSwapRouter.getCurrentPriceRatio(self.info.toId(), dsId)
        returns (uint256, uint256 _ctRatio) {
            ratio = _ctRatio;
        } catch {}
    }

    function __provideLiquidity(
        State storage self,
        uint256 raAmount,
        uint256 ctAmount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        IUniswapV2Router02 ammRouter,
        uint256 dsId
    ) internal {
        // no need to provide liquidity if the amount is 0
        if (raAmount == 0 && ctAmount == 0) {
            return;
        }

        PsmLibrary.unsafeIssueToLv(self, ctAmount);

        __addLiquidityToAmmUnchecked(
            self,
            raAmount,
            ctAmount,
            self.info.redemptionAsset(),
            ctAddress,
            ammRouter
        );

        _addFlashSwapReserve(self, flashSwapRouter, self.ds[dsId], ctAmount);
    }

    function __provideAmmLiquidityFromPool(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        IUniswapV2Router02 ammRouter
    ) internal {
        uint256 dsId = self.globalAssetIdx;

        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (uint256 ra, uint256 ct) = self.vault.pool.rationedToAmm(ctRatio);

        __provideLiquidity(
            self,
            ra,
            ct,
            flashSwapRouter,
            ctAddress,
            ammRouter,
            dsId
        );

        self.vault.pool.resetAmmPool();
    }

    function deposit(
        State storage self,
        address from,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter
    ) external {
        safeBeforeExpired(self);
        self.vault.balances.ra.lockUnchecked(amount, from);
        __provideLiquidityWithRatio(
            self,
            amount,
            flashSwapRouter,
            self.ds[self.globalAssetIdx].ct,
            ammRouter
        );
        self.vault.lv.issue(from, amount);
    }

    // preview a deposit action with current exchange rate,
    // returns the amount of shares(share pool token) that user will receive
    function previewDeposit(
        uint256 amount
    ) external pure returns (uint256 lvReceived) {
        lvReceived = amount;
    }

    function _requestRedemption(
        State storage self,
        address owner,
        uint256 amount
    ) internal {
        self.vault.pool.withdrawEligible[owner] += amount;
        self.vault.pool.withdrawalPool.atrributedLv += amount;
        self.vault.lv.lockFrom(amount, owner);
    }

    function requestRedemption(
        State storage self,
        address owner,
        uint256 amount,
        bytes memory rawLvPermitSig,
        uint256 deadline
    ) external {
        safeBeforeExpired(self);
        DepegSwapLibrary.permit(
            self.vault.lv._address,
            rawLvPermitSig,
            owner,
            self.vault.lv._address,
            amount,
            deadline
        );
        _requestRedemption(self, owner, amount);
    }

    function requestRedemption(
        State storage self,
        address owner,
        uint256 amount
    ) external {
        safeBeforeExpired(self);
        _requestRedemption(self, owner, amount);
    }

    function lvLockedFor(
        State storage self,
        address owner
    ) external view returns (uint256) {
        return self.vault.pool.withdrawEligible[owner];
    }

    function cancelRedemptionRequest(
        State storage self,
        address owner,
        uint256 amount
    ) external {
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
    ) external {
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

    function __liquidateUnchecked(
        State storage self,
        address raAddress,
        address ctAddress,
        IUniswapV2Router02 ammRouter,
        IUniswapV2Pair ammPair,
        uint256 lp
    ) internal returns (uint256 raReceived, uint256 ctReceived) {
        ammPair.approve(address(ammRouter), lp);

        (raReceived, ctReceived) = ammRouter.removeLiquidity(
            raAddress,
            ctAddress,
            lp,
            // 100% tolerance
            0,
            // 100% tolerance
            0,
            address(this),
            block.timestamp
        );

        (raReceived, ctReceived) = MinimalUniswapV2Library
            .reverseSortWithAmount224(
                ammPair.token0(),
                ammPair.token1(),
                raAddress,
                ctAddress,
                raReceived,
                ctReceived
            );

        self.vault.config.lpBalance -= lp;
    }

    // used by early redeem, will liquidate LP partially
    function _liquidateLpPartial(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter,
        uint256 lvRedeemed
    ) internal returns (uint256 ra) {
        uint256 raPerLp;
        uint256 ctPerLp;
        uint256 raPerLv;
        uint256 ammCtBalance;

        (raPerLv, , raPerLp, ctPerLp) = __calculateCtBalanceWithRate(
            self,
            flashSwapRouter,
            dsId
        );

        (ra, ammCtBalance) = __liquidateUnchecked(
            self,
            self.info.pair1,
            self.ds[dsId].ct,
            ammRouter,
            IUniswapV2Pair(self.ds[dsId].ammPair),
            MathHelper.convertToLp(raPerLv, raPerLp, lvRedeemed)
        );

        ra += _redeemCtDsAndSellExcessCt(
            self,
            dsId,
            ammRouter,
            flashSwapRouter,
            ammCtBalance
        );
    }

    function _redeemCtDsAndSellExcessCt(
        State storage self,
        uint256 dsId,
        IUniswapV2Router02 ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        uint256 ammCtBalance
    ) internal returns (uint256 ra) {
        uint256 reservedDs = flashSwapRouter.getLvReserve(
            self.info.toId(),
            dsId
        );

        uint256 redeemAmount = reservedDs >= ammCtBalance
            ? ammCtBalance
            : reservedDs;

        reservedDs = flashSwapRouter.emptyReservePartial(
            self.info.toId(),
            dsId,
            redeemAmount
        );

        ra += redeemAmount;
        PsmLibrary.lvRedeemRaWithCtDs(self, redeemAmount, dsId);

        uint256 ctSellAmount = reservedDs >= ammCtBalance
            ? 0
            : ammCtBalance - reservedDs;

        DepegSwap storage ds = self.ds[dsId];
        address[] memory path = new address[](2);
        path[0] = ds.ct;
        path[1] = self.info.pair1;

        ERC20(ds.ct).approve(address(ammRouter), ctSellAmount);

        if (ctSellAmount != 0) {
            // 100% tolerance, to ensure this not fail
            ra += ammRouter.swapExactTokensForTokens(
                ctSellAmount,
                0,
                path,
                address(this),
                block.timestamp
            )[1];
        }
    }

    function _liquidatedLp(
        State storage self,
        uint256 dsId,
        IUniswapV2Router02 ammRouter,
        IDsFlashSwapCore flashSwapRouter
    ) internal {
        DepegSwap storage ds = self.ds[dsId];

        // if there's no LP, then there's nothing to liquidate
        if (self.vault.config.lpBalance == 0) {
            return;
        }

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
        (uint256 raAmm, uint256 ctAmm) = __liquidateUnchecked(
            self,
            self.info.pair1,
            self.ds[dsId].ct,
            ammRouter,
            IUniswapV2Pair(ds.ammPair),
            self.vault.config.lpBalance
        );

        uint256 reservedDs = flashSwapRouter.emptyReserve(
            self.info.toId(),
            dsId
        );

        uint256 redeemAmount = reservedDs >= ctAmm ? ctAmm : reservedDs;
        PsmLibrary.lvRedeemRaWithCtDs(self, redeemAmount, dsId);

        // if the reserved DS is more than the CT that's available from liquidating the AMM LP
        // then there's no CT we can use to effectively redeem RA + PA from the PSM
        uint256 ctAttributedToPa = reservedDs >= ctAmm ? 0 : ctAmm - reservedDs;

        uint256 psmPa;
        uint256 psmRa;

        if (ctAttributedToPa != 0) {
            (psmPa, psmRa) = PsmLibrary.lvRedeemRaPaWithCt(
                self,
                ctAttributedToPa,
                dsId
            );
        }

        psmRa += redeemAmount;

        self.vault.pool.reserve(
            self.vault.lv.totalIssued(),
            raAmm + psmRa,
            psmPa
        );
    }

    function reservedForWithdrawal(
        State storage self
    ) external view returns (uint256 ra, uint256 pa) {
        ra = self.vault.pool.withdrawalPool.raBalance;
        pa = self.vault.pool.withdrawalPool.paBalance;
    }

    function _tryLiquidateLpAndRedeemCtToPsm(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter
    ) internal view returns (uint256 totalRa, uint256 pa) {
        uint256 ammCtBalance;

        (totalRa, ammCtBalance) = __calculateTotalRaAndCtBalance(
            self,
            flashSwapRouter,
            dsId
        );

        uint256 reservedDs = flashSwapRouter.getLvReserve(
            self.info.toId(),
            dsId
        );

        // pair DS and CT to redeem RA
        totalRa += reservedDs > ammCtBalance ? ammCtBalance : reservedDs;

        uint256 raFromCt;
        // redeem CT to get RA + PA
        (pa, raFromCt) = PsmLibrary.previewRedeemWithCt(
            self,
            dsId,
            // CT attributed to PA
            reservedDs > ammCtBalance ? 0 : ammCtBalance - reservedDs
        );
    }

    // duplate function to avoid stack too deep error
    function __calculateTotalRaAndCtBalance(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        uint256 dsId
    ) internal view returns (uint256 totalRa, uint256 ammCtBalance) {
        (uint256 raReserve, uint256 ctReserve, ) = flashSwapRouter
            .getUniV2pair(self.info.toId(), dsId)
            .getReserves();

        (
            ,
            ,
            ,
            ,
            totalRa,
            ammCtBalance
        ) = __calculateTotalRaAndCtBalanceWithReserve(
            self,
            raReserve,
            ctReserve,
            flashSwapRouter.getLvReserve(self.info.toId(), dsId)
        );
    }

    // duplate function to avoid stack too deep error
    function __calculateCtBalanceWithRate(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        uint256 dsId
    )
        internal
        view
        returns (
            uint256 raPerLv,
            uint256 ctPerLv,
            uint256 raPerLp,
            uint256 ctPerLp
        )
    {
        (uint256 raReserve, uint256 ctReserve, ) = flashSwapRouter
            .getUniV2pair(self.info.toId(), dsId)
            .getReserves();

        (
            ,
            ,
            raPerLv,
            ctPerLv,
            raPerLp,
            ctPerLp
        ) = __calculateTotalRaAndCtBalanceWithReserve(
            self,
            raReserve,
            ctReserve,
            flashSwapRouter.getLvReserve(self.info.toId(), dsId)
        );
    }

    function __calculateTotalRaAndCtBalanceWithReserve(
        State storage self,
        uint256 raReserve,
        uint256 ctReserve,
        uint256 lpSupply
    )
        internal
        view
        returns (
            uint256 totalRa,
            uint256 ammCtBalance,
            uint256 raPerLv,
            uint256 ctPerLv,
            uint256 raPerLp,
            uint256 ctPerLp
        )
    {
        (raPerLv, ctPerLv, raPerLp, ctPerLp, totalRa, ammCtBalance) = MathHelper
            .calculateLvValueFromUniV2Lp(
                lpSupply,
                self.vault.config.lpBalance,
                raReserve,
                ctReserve,
                Asset(self.vault.lv._address).totalSupply()
            );
    }

    function _tryLiquidateLpAndSellCtToAmm(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        uint256 lvRedeemed
    ) internal view returns (uint256 totalRa, uint256 lpLiquidated) {
        (
            uint256 raPerLv,
            uint256 ctPerLv,
            uint256 raPerLp,
            uint256 ctPerLp
        ) = __calculateCtBalanceWithRate(self, flashSwapRouter, dsId);

        totalRa = (raPerLv * lvRedeemed) / 1e18;
        uint256 ammCtBalance = (ctPerLv * lvRedeemed) / 1e18;

        lpLiquidated = MathHelper.convertToLp(raPerLv, raPerLp, lvRedeemed);

        // pair DS and CT to redeem RA
        totalRa += flashSwapRouter.getLvReserve(self.info.toId(), dsId) >
            ammCtBalance
            ? ammCtBalance
            : flashSwapRouter.getLvReserve(self.info.toId(), dsId);

        uint256 excessCt = flashSwapRouter.getLvReserve(
            self.info.toId(),
            dsId
        ) > ammCtBalance
            ? 0
            : ammCtBalance -
                flashSwapRouter.getLvReserve(self.info.toId(), dsId);

        totalRa += _trySellCtToAmm(
            self,
            dsId,
            flashSwapRouter,
            excessCt,
            ctPerLp
        );
    }

    function _trySellCtToAmm(
        State storage self,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        uint256 excessCt,
        uint256 ctPerLp
    ) internal view returns (uint256 ra) {
        if (excessCt == 0) {
            return 0;
        }

        (uint256 raReserve, uint256 ctReserve, ) = flashSwapRouter
            .getUniV2pair(self.info.toId(), dsId)
            .getReserves();
        uint256 ct = (excessCt * ctPerLp) / 1e18;
        ra = MinimalUniswapV2Library.getAmountOut(ct, ctReserve, raReserve);
    }

    function _redeemExpired(
        State storage self,
        DepegSwap storage ds,
        address owner,
        uint256 amount,
        IUniswapV2Router02 ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        uint256 dsId
    ) internal{
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
            _liquidatedLp(self, dsId, ammRouter, flashSwapRouter);
            assert(self.vault.balances.ra.locked == 0);
        }
    }

    function _processRedeemExpired(
        State storage self,
        address owner,
        address receiver,
        uint256 attributedRa,
        uint256 attributedPa,
        uint256 burnUserAmount,
        uint256 burnSelfAmount
    ) internal {
        //ra
        IERC20(self.info.pair1).transfer(receiver, attributedRa);
        //pa
        IERC20(self.info.pair0).transfer(receiver, attributedPa);

        self.vault.lv.burnSelf(burnSelfAmount);

        if (burnUserAmount != 0) {
            ERC20Burnable(self.vault.lv._address).burnFrom(
                owner,
                burnUserAmount
            );
        }
    }

    function redeemExpired(
        State storage self,
        address owner,
        address receiver,
        uint256 amount,
        IUniswapV2Router02 ammRouter,
        IDsFlashSwapCore flashSwapRouter,
        bytes memory rawLvPermitSig,
        uint256 deadline
    ) external returns (uint256 attributedRa, uint256 attributedPa) {
        {
            uint256 dsId = self.globalAssetIdx;
            DepegSwap storage ds = self.ds[dsId];

            _redeemExpired(self, ds, owner, amount, ammRouter, flashSwapRouter, dsId);
        }

        uint256 burnUserAmount;
        uint256 burnSelfAmount;

        (attributedRa, attributedPa, burnUserAmount, burnSelfAmount) = self
            .vault
            .pool
            .redeem(amount, owner);
        assert(burnSelfAmount + burnUserAmount == amount);

        DepegSwapLibrary.permit(
            self.vault.lv._address,
            rawLvPermitSig,
            owner,
            address(this),
            burnUserAmount,
            deadline
        );
        _processRedeemExpired(self, owner, receiver, attributedRa, attributedPa, burnUserAmount, burnSelfAmount);
    }

    function redeemExpired(
        State storage self,
        address owner,
        address receiver,
        uint256 amount,
        IUniswapV2Router02 ammRouter,
        IDsFlashSwapCore flashSwapRouter
    ) external returns (uint256 attributedRa, uint256 attributedPa) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        _redeemExpired(self, ds, owner, amount, ammRouter, flashSwapRouter, dsId);
        uint256 burnUserAmount;
        uint256 burnSelfAmount;

        (attributedRa, attributedPa, burnUserAmount, burnSelfAmount) = self
            .vault
            .pool
            .redeem(amount, owner);
        assert(burnSelfAmount + burnUserAmount == amount);

        _processRedeemExpired(self, owner, receiver, attributedRa, attributedPa, burnUserAmount, burnSelfAmount);
    }

    function previewRedeemExpired(
        State storage self,
        uint256 amount,
        address owner,
        IDsFlashSwapCore flashSwapRouter
    )
        external
        view
        returns (
            uint256 attributedRa,
            uint256 attributedPa,
            uint256 approvedAmount
        )
    {
        DepegSwap storage ds = self.ds[self.globalAssetIdx];

        if (self.vault.pool.withdrawEligible[owner] == 0 && !ds.isExpired()) {
            revert Unauthorized(owner);
        }

        // user can only redeem up to the amount they requested, when there's a DS active
        // if there's no DS active, then there's no cap on the amount of LV that can be redeemed
        if (
            !ds.isExpired() && self.vault.pool.withdrawEligible[owner] < amount
        ) {
            revert InsufficientBalance(
                owner,
                amount,
                self.vault.pool.withdrawEligible[owner]
            );
        }

        VaultWithdrawalPool memory withdrawalPool = self
            .vault
            .pool
            .withdrawalPool;

        VaultAmmLiquidityPool memory ammLiquidityPool = self
            .vault
            .pool
            .ammLiquidityPool;

        if (
            ds.isExpired() && !self.vault.lpLiquidated.get(self.globalAssetIdx)
        ) {
            (uint256 totalRa, uint256 pa) = _tryLiquidateLpAndRedeemCtToPsm(
                self,
                self.globalAssetIdx,
                flashSwapRouter
            );

            VaultPoolLibrary.tryReserve(
                withdrawalPool,
                ammLiquidityPool,
                self.vault.lv.totalIssued(),
                totalRa,
                pa
            );
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

    // IMPORTANT : only psm and early redeem can call this function
    function provideLiquidityWithFee(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter
    ) public {
        __provideLiquidityWithRatio(
            self,
            amount,
            flashSwapRouter,
            self.ds[self.globalAssetIdx].ct,
            ammRouter
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
    // TODO : fix this
    function _redeemEarly(
        State storage self,
        address owner,
        address receiver,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter
    ) internal returns (uint256 received, uint256 fee, uint256 feePrecentage) {
        feePrecentage = self.vault.config.fee;

        received = _liquidateLpPartial(
            self,
            self.globalAssetIdx,
            flashSwapRouter,
            ammRouter,
            amount
        );

        fee = MathHelper.calculatePrecentageFee(received, feePrecentage);

        provideLiquidityWithFee(self, fee, flashSwapRouter, ammRouter);
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

    function redeemEarly(
        State storage self,
        address owner,
        address receiver,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter,
        bytes memory rawLvPermitSig,
        uint256 deadline
    ) external returns (uint256 received, uint256 fee, uint256 feePrecentage) {
        safeBeforeExpired(self);
        DepegSwapLibrary.permit(
            self.vault.lv._address,
            rawLvPermitSig,
            owner,
            address(this),
            amount,
            deadline
        );
        return _redeemEarly(self, owner, receiver, amount, flashSwapRouter, ammRouter);
    }

    function redeemEarly(
        State storage self,
        address owner,
        address receiver,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        IUniswapV2Router02 ammRouter
    ) external returns (uint256 received, uint256 fee, uint256 feePrecentage) {
        safeBeforeExpired(self);
        return _redeemEarly(self, owner, receiver, amount, flashSwapRouter, ammRouter);
    }

    function previewRedeemEarly(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter
    )
        external
        view
        returns (uint256 received, uint256 fee, uint256 feePrecentage)
    {
        safeBeforeExpired(self);

        feePrecentage = self.vault.config.fee;

        (received, ) = _tryLiquidateLpAndSellCtToAmm(
            self,
            self.globalAssetIdx,
            flashSwapRouter,
            amount
        );

        fee = MathHelper.calculatePrecentageFee(received, feePrecentage);

        received -= fee;
    }
}
