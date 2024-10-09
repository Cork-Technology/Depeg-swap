pragma solidity ^0.8.24;

import {AssetPair, ReserveState, DsFlashSwaplibrary} from "../../libraries/DsFlashSwap.sol";
import {SwapperMathLibrary} from "../../libraries/DsSwapperMathLib.sol";
import {MathHelper} from "../../libraries/MathHelper.sol";
import {Id} from "../../libraries/Pair.sol";
import {IDsFlashSwapCore, IDsFlashSwapUtility} from "../../interfaces/IDsFlashSwapRouter.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IUniswapV2Callee} from "../../interfaces/uniswap-v2/callee.sol";
import {IUniswapV2Pair} from "../../interfaces/uniswap-v2/pair.sol";
import {MinimalUniswapV2Library} from "../../libraries/uni-v2/UniswapV2Library.sol";
import {IPSMcore} from "../../interfaces/IPSMcore.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {Asset} from "../assets/Asset.sol";
import {DepegSwapLibrary} from "../../libraries/DepegSwapLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Router contract for Flashswap
 * @author Cork Team
 * @notice Router contract for implementing flashswaps for DS/CT
 */
contract RouterState is
    IDsFlashSwapUtility,
    IDsFlashSwapCore,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IUniswapV2Callee
{
    using DsFlashSwaplibrary for ReserveState;
    using DsFlashSwaplibrary for AssetPair;
    using SafeERC20 for IERC20;

    bytes32 public constant MODULE_CORE = keccak256("MODULE_CORE");
    bytes32 public constant CONFIG = keccak256("CONFIG");

    address public _moduleCore;

    /// @notice __gap variable to prevent storage collisions
    uint256[49] __gap;

    modifier onlyDefaultAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotDefaultAdmin();
        }
        _;
    }

    modifier onlyModuleCore() {
        if (!hasRole(MODULE_CORE, msg.sender)) {
            revert NotModuleCore();
        }
        _;
    }

    modifier onlyConfig() {
        if (!hasRole(CONFIG, msg.sender)) {
            revert NotConfig();
        }
        _;
    }

    function updateDiscountRateInDdays(Id id, uint256 discountRateInDays) external override onlyConfig {
        reserves[id].decayDiscountRateInDays = discountRateInDays;
    }

    function getCurrentCumulativeHPA(Id id) external view returns (uint256 hpaCummulative) {
        hpaCummulative = reserves[id].getCurrentCumulativeHPA();
    }

    function getCurrentEffectiveHPA(Id id) external view returns (uint256 hpa) {
        hpa = reserves[id].getEffectiveHPA();
    }

    function initialize(address config) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONFIG, config);
    }

    mapping(Id => ReserveState) internal reserves;

    function _authorizeUpgrade(address newImplementation) internal override onlyConfig {}

    function setModuleCore(address moduleCore) external onlyDefaultAdmin {
        _moduleCore = moduleCore;
        _grantRole(MODULE_CORE, moduleCore);
    }

    function onNewIssuance(Id reserveId, uint256 dsId, address ds, address pair, address ra, address ct)
        external
        override
        onlyModuleCore
    {
        reserves[reserveId].onNewIssuance(dsId, ds, pair, ra, ct);

        emit NewIssuance(reserveId, dsId, ds, pair);
    }

    /// @notice set the discount rate rate and rollover for the new issuance
    /// @dev needed to avoid stack to deep errors. MUST be called after onNewIssuance and only by moduleCore at new issuance
    function setDecayDiscountAndRolloverPeriodOnNewIssuance(
        Id reserveId,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) external override onlyModuleCore {
        ReserveState storage self = reserves[reserveId];
        self.decayDiscountRateInDays = decayDiscountRateInDays;
        self.rolloverEndInBlockNumber = block.number + rolloverPeriodInblocks;
    }

    function getAmmReserve(Id id, uint256 dsId) external view override returns (uint112 raReserve, uint112 ctReserve) {
        (raReserve, ctReserve) = reserves[id].getReserve(dsId);
    }

    function getLvReserve(Id id, uint256 dsId) external view override returns (uint256 lvReserve) {
        return reserves[id].ds[dsId].lvReserve;
    }

    function getPsmReserve(Id id, uint256 dsId) external view override returns (uint256 psmReserve) {
        return reserves[id].ds[dsId].psmReserve;
    }

    function getUniV2pair(Id id, uint256 dsId) external view override returns (IUniswapV2Pair pair) {
        return reserves[id].getPair(dsId);
    }

    function emptyReserveLv(Id reserveId, uint256 dsId) external override onlyModuleCore returns (uint256 amount) {
        amount = reserves[reserveId].emptyReserveLv(dsId, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePartialLv(Id reserveId, uint256 dsId, uint256 amount)
        external
        override
        onlyModuleCore
        returns (uint256 emptied)
    {
        emptied = reserves[reserveId].emptyReservePartialLv(dsId, amount, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePsm(Id reserveId, uint256 dsId) external override onlyModuleCore returns (uint256 amount) {
        amount = reserves[reserveId].emptyReservePsm(dsId, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePartialPsm(Id reserveId, uint256 dsId, uint256 amount)
        external
        override
        onlyModuleCore
        returns (uint256 emptied)
    {
        emptied = reserves[reserveId].emptyReservePartialPsm(dsId, amount, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function getCurrentPriceRatio(Id id, uint256 dsId)
        external
        view
        override
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        (raPriceRatio, ctPriceRatio) = reserves[id].getPriceRatio(dsId);
    }

    function addReserveLv(Id id, uint256 dsId, uint256 amount) external override onlyModuleCore {
        reserves[id].addReserveLv(dsId, amount, _moduleCore);
        emit ReserveAdded(id, dsId, amount);
    }

    function addReservePsm(Id id, uint256 dsId, uint256 amount) external override onlyModuleCore {
        reserves[id].addReservePsm(dsId, amount, _moduleCore);
        emit ReserveAdded(id, dsId, amount);
    }

    /// will return that can't be filled from the reserve, this happens when the total reserve is less than the amount requested
    function _swapRaForDsViaRollover(Id reserveId, uint256 dsId, uint256 amountRa, uint256 amountOutMin)
        internal
        returns (uint256 raLeft, uint256 dsReceived)
    {
        // this means that we ignore and don't do rollover sale when it's first issuance or it's not rollover time
        if (dsId == DsFlashSwaplibrary.FIRST_ISSUANCE || !reserves[reserveId].rolloverSale()) {
            // noop and return back the full amountRa
            return (amountRa, 0);
        }

        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        uint256 lvProfit;
        uint256 psmProfit;
        dsReceived;
        uint256 lvReserveUsed;
        uint256 psmReserveUsed;

        (lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed) =
            SwapperMathLibrary.calculateRolloverSale(assetPair.lvReserve, assetPair.psmReserve, amountRa, self.hpa);

        if (dsReceived < amountOutMin) {
            revert InsufficientOutputAmount();
        }

        assetPair.psmReserve -= psmReserveUsed;
        assetPair.lvReserve -= lvReserveUsed;

        IERC20(assetPair.ra).safeTransfer(_moduleCore, lvProfit + psmProfit);

        IPSMcore(_moduleCore).psmAcceptFlashSwapProfit(reserveId, psmProfit);
        IVault(_moduleCore).lvAcceptRolloverProfit(reserveId, lvProfit);

        IERC20(assetPair.ds).safeTransfer(msg.sender, dsReceived);

        emit RolloverSold(reserveId, dsId, msg.sender, dsReceived, amountRa - raLeft);
    }

    function _previewSwapRaForDsViaRollover(Id reserveId, uint256 dsId, uint256 amountRa)
        internal
        view
        returns (uint256 raLeft, uint256 dsReceived)
    {
        if (dsId == DsFlashSwaplibrary.FIRST_ISSUANCE || !reserves[reserveId].rolloverSale()) {
            return (amountRa, 0);
        }

        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        uint256 lvProfit;
        uint256 psmProfit;
        dsReceived;
        uint256 lvReserveUsed;
        uint256 psmReserveUsed;

        (lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed) =
            SwapperMathLibrary.calculateRolloverSale(assetPair.lvReserve, assetPair.psmReserve, amountRa, self.hpa);
    }

    function rolloverSaleEnds(Id reserveId) external view returns (uint256 endInBlockNumber) {
        return reserves[reserveId].rolloverEndInBlockNumber;
    }

    function _swapRaforDs(
        ReserveState storage self,
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin
    ) internal returns (uint256 amountOut) {
        uint256 borrowedAmount;

        uint256 dsReceived;
        // try to swap the RA for DS via rollover, this will noop if the condition for rollover is not met
        (amount, dsReceived) = _swapRaForDsViaRollover(reserveId, dsId, amount, amountOutMin);

        // short circuit if all the swap is filled using rollover
        if (amount == 0) {
            return dsReceived;
        }

        // calculate the amount of DS tokens attributed
        (amountOut, borrowedAmount,) = assetPair.getAmountOutBuyDS(amount);

        // calculate the amount of DS tokens that will be sold from reserve
        uint256 amountSellFromReserve =
            amountOut - MathHelper.calculatePercentageFee(self.reserveSellPressurePercentage, amountOut);

        // sell all tokens if the sell amount is higher than the available reserve
        amountSellFromReserve = assetPair.lvReserve + assetPair.psmReserve < amountSellFromReserve
            ? assetPair.lvReserve + assetPair.psmReserve
            : amountSellFromReserve;

        // sell the DS tokens from the reserve if there's any
        if (amountSellFromReserve != 0) {
            // sell the DS tokens from the reserve and accrue value to LV holders
            // it's safe to transfer all profit to the module core since the profit for each PSM and LV is calculated separately and we invoke
            // the profit acceptance function for each of them
            //
            // this function can fail, if there's not enough CT liquidity to sell the DS tokens, in that case, we skip the selling part and let user buy the DS tokens
            (uint256 profitRa,, bool success) =
                __swapDsforRa(assetPair, reserveId, dsId, amountSellFromReserve, 0, _moduleCore);

            if (success) {
                // calculate the amount of DS tokens that will be sold from both reserve
                uint256 lvReserveUsed = assetPair.lvReserve * amountSellFromReserve * 1e18
                    / (assetPair.lvReserve + assetPair.psmReserve) / 1e18;
                uint256 psmReserveUsed = amountSellFromReserve - lvReserveUsed;

                // decrement reserve
                assetPair.lvReserve -= lvReserveUsed;
                assetPair.psmReserve -= psmReserveUsed;

                // calculate the profit of the liquidity vault
                uint256 vaultProfit = profitRa * lvReserveUsed / amountSellFromReserve;

                // send profit to the vault and PSM
                IVault(_moduleCore).provideLiquidityWithFlashSwapFee(reserveId, vaultProfit);
                // send profit to the PSM
                IPSMcore(_moduleCore).psmAcceptFlashSwapProfit(reserveId, profitRa - vaultProfit);

                // recalculate the amount of DS tokens attributed, since we sold some from the reserve
                (amountOut, borrowedAmount,) = assetPair.getAmountOutBuyDS(amount);
            }
        }

        // slippage protection, revert if the amount of DS tokens received is less than the minimum amount
        if (amountOut + dsReceived < amountOutMin) {
            revert InsufficientOutputAmount();
        }

        // trigger flash swaps and send the attributed DS tokens to the user
        __flashSwap(assetPair, assetPair.pair, borrowedAmount, 0, dsId, reserveId, true, amountOut, msg.sender);

        // add the amount of DS tokens from the rollover, if any
        amountOut += dsReceived;
    }

    /**
     * @notice Swaps RA for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @param amountOutMin the minimum amount of DS to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapRaforDs
     * @param rawRaPermitSig raw signature for RA token approval
     * @param deadline the deadline of given permit signature
     * @return amountOut amount of DS that's received
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address user,
        bytes memory rawRaPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        if (!DsFlashSwaplibrary.isRAsupportsPermit(address(assetPair.ra))) {
            revert PermitNotSupported();
        }

        DepegSwapLibrary.permit(address(assetPair.ra), rawRaPermitSig, user, address(this), amount, deadline);
        IERC20(assetPair.ra).safeTransferFrom(user, address(this), amount);

        amountOut = _swapRaforDs(self, assetPair, reserveId, dsId, amount, amountOutMin);

        self.recalculateHPA(dsId, amount, amountOut);

        emit RaSwapped(reserveId, dsId, user, amount, amountOut);
    }

    /**
     * @notice Swaps RA for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @param amountOutMin the minimum amount of DS to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapRaforDs
     * @return amountOut amount of DS that's received
     */
    function swapRaforDs(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        returns (uint256 amountOut)
    {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        IERC20(assetPair.ra).safeTransferFrom(msg.sender, address(this), amount);

        amountOut = _swapRaforDs(self, assetPair, reserveId, dsId, amount, amountOutMin);

        self.recalculateHPA(dsId, amount, amountOut);

        emit RaSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    // TODO : add rollover and subtract reserve from the two reserve
    /**
     * @notice Preview the amount of DS that will be received from swapping RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @return amountOut amount of DS that will be received
     */
    function previewSwapRaforDs(Id reserveId, uint256 dsId, uint256 amount) external view returns (uint256 amountOut) {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        uint256 dsReceived;

        // preview rollover, if applicable
        (amount, dsReceived) = _previewSwapRaForDsViaRollover(reserveId, dsId, amount);

        // short circuit if all the swap is filled using rollover
        if (amount == 0) {
            return dsReceived;
        }

        (amountOut,,) = assetPair.getAmountOutBuyDS(amount);

        // calculate the amount of DS tokens that will be sold from reserve
        uint256 amountSellFromReserve =
            amountOut - MathHelper.calculatePercentageFee(self.reserveSellPressurePercentage, amountOut);

        // sell all tokens if the sell amount is higher than the available reserve
        amountSellFromReserve = assetPair.lvReserve + assetPair.psmReserve < amountSellFromReserve
            ? assetPair.lvReserve + assetPair.psmReserve
            : amountSellFromReserve;

        // sell the DS tokens from the reserve if there's any
        if (amountSellFromReserve != 0) {
            (,, bool success) = assetPair.getAmountOutSellDS(amountSellFromReserve);

            if (success) {
                amountOut = _trySellFromReserve(self, assetPair, amountSellFromReserve, dsId, amount);
            }
        }

        // add the amount of DS tokens from the rollover, if any
        // we add here the last for simpler control flow, since this way the logic of regular swap
        // don't need to care about how much token is received from the rollover sale
        amountOut += dsReceived;
    }

    function _trySellFromReserve(
        ReserveState storage self,
        AssetPair storage assetPair,
        uint256 amountSellFromReserve,
        uint256 dsId,
        uint256 amount
    ) private view returns (uint256 amountOut) {
        (uint112 raReserve, uint112 ctReserve) = assetPair.getReservesSorted();

        // we borrow the same amount of CT tokens from the reserve
        ctReserve -= uint112(amountSellFromReserve);

        (uint256 profit, uint256 raAdded,) = assetPair.getAmountOutSellDS(amountSellFromReserve);

        raReserve += uint112(raAdded);

        // emulate Vault way of adding liquidity using RA from selling DS reserve
        (, uint256 ratio) = self.tryGetPriceRatioAfterSellDs(dsId, amountSellFromReserve, raAdded);
        uint256 ctAdded;
        uint256 lvReserveUsed =
            assetPair.lvReserve * amountSellFromReserve * 1e18 / (assetPair.lvReserve + assetPair.psmReserve) / 1e18; // calculate the profit of the liquidity vault

        // get the vault profit, we don't care about the PSM profit since it'll be sent to PSM
        profit = profit * lvReserveUsed / amountSellFromReserve;

        // use the vault profit
        (raAdded, ctAdded) =
            MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(profit, ratio, assetPair.ds.exchangeRate());

        raReserve += uint112(raAdded);
        ctReserve += uint112(ctAdded);

        // update amountOut since we sold some from the reserve
        uint256 exchangeRates = assetPair.ds.exchangeRate();
        (, amountOut) = SwapperMathLibrary.getAmountOutBuyDs(exchangeRates, raReserve, ctReserve, amount);
    }

    function isRolloverSale(Id id, uint256 dsId) external view returns (bool) {
        return reserves[id].rolloverSale();
    }

    /**
     * @notice Swaps DS for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapDsforRa
     * @param rawDsPermitSig raw signature for DS token approval
     * @param deadline the deadline of given permit signature
     * @return amountOut amount of RA that's received
     */
    function swapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address user,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        DepegSwapLibrary.permit(address(assetPair.ds), rawDsPermitSig, user, address(this), amount, deadline);
        assetPair.ds.transferFrom(user, address(this), amount);

        bool success;
        uint256 repaymentAmount;
        (amountOut, repaymentAmount, success) = __swapDsforRa(assetPair, reserveId, dsId, amount, amountOutMin, user);

        if (!success) {
            (uint112 raReserve, uint112 ctReserve) = assetPair.getReservesSorted();
            revert IDsFlashSwapCore.InsufficientLiquidity(raReserve, ctReserve, repaymentAmount);
        }
        self.recalculateHPA(dsId, amountOut, amount);

        emit DsSwapped(reserveId, dsId, user, amount, amountOut);
    }

    /**
     * @notice Swaps DS for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapDsforRa
     * @return amountOut amount of RA that's received
     */
    function swapDsforRa(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        returns (uint256 amountOut)
    {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        assetPair.ds.transferFrom(msg.sender, address(this), amount);

        bool success;
        uint256 repaymentAmount;
        (amountOut, repaymentAmount, success) =
            __swapDsforRa(assetPair, reserveId, dsId, amount, amountOutMin, msg.sender);

        if (!success) {
            (uint112 raReserve, uint112 ctReserve) = assetPair.getReservesSorted();
            revert IDsFlashSwapCore.InsufficientLiquidity(raReserve, ctReserve, repaymentAmount);
        }

        self.recalculateHPA(dsId, amountOut, amount);

        emit DsSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    function __swapDsforRa(
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address caller
    ) internal returns (uint256 amountOut, uint256 repaymentAmount, bool success) {
        (amountOut, repaymentAmount, success) = assetPair.getAmountOutSellDS(amount);

        if (!success) {
            return (amountOut, repaymentAmount, success);
        }

        if (amountOut < amountOutMin) {
            revert InsufficientOutputAmount();
        }

        __flashSwap(assetPair, assetPair.pair, 0, amount, dsId, reserveId, false, amountOut, caller);
    }

    /**
     * @notice Preview the amount of RA that will be received from swapping DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @return amountOut amount of RA that will be received
     */
    function previewSwapDsforRa(Id reserveId, uint256 dsId, uint256 amount) external view returns (uint256 amountOut) {
        AssetPair storage assetPair = reserves[reserveId].ds[dsId];

        bool success;
        uint256 repaymentAmount;

        (amountOut, repaymentAmount, success) = assetPair.getAmountOutSellDS(amount);

        if (!success) {
            (uint112 raReserve, uint112 ctReserve) = assetPair.getReservesSorted();
            revert IDsFlashSwapCore.InsufficientLiquidity(raReserve, ctReserve, repaymentAmount);
        }
    }

    function __flashSwap(
        AssetPair storage assetPair,
        IUniswapV2Pair univ2Pair,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 dsId,
        Id reserveId,
        bool buyDs,
        // extra data to be encoded into the callback
        // will be interpreted as the ra attributed to user for selling ds
        // and ds attributed to user for buying ra
        uint256 extraData,
        address caller
    ) internal {
        (,, uint256 amount0out, uint256 amount1out) = MinimalUniswapV2Library.sortTokensUnsafeWithAmount(
            address(assetPair.ra), address(assetPair.ct), raAmount, ctAmount
        );

        bytes memory data = abi.encode(reserveId, dsId, buyDs, caller, extraData);

        univ2Pair.swap(amount0out, amount1out, address(this), data);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        (Id reserveId, uint256 dsId, bool buyDs, address caller, uint256 extraData) =
            abi.decode(data, (Id, uint256, bool, address, uint256));

        ReserveState storage self = reserves[reserveId];
        IUniswapV2Pair pair = self.getPair(dsId);

        assert(msg.sender == address(pair));
        assert(sender == address(this));

        if (buyDs) {
            __afterFlashswapBuy(self, reserveId, dsId, caller, extraData);
        } else {
            uint256 amount = amount0 == 0 ? amount1 : amount0;

            __afterFlashswapSell(self, amount, reserveId, dsId, caller, extraData);
        }
    }

    function __afterFlashswapBuy(
        ReserveState storage self,
        Id reserveId,
        uint256 dsId,
        address caller,
        uint256 dsAttributed
    ) internal {
        AssetPair storage assetPair = self.ds[dsId];
        IERC20(assetPair.ra).safeIncreaseAllowance(_moduleCore, dsAttributed);

        IPSMcore psm = IPSMcore(_moduleCore);
        psm.depositPsm(reserveId, dsAttributed);

        // should be the same, we don't compare with the RA amount since we maybe dealing
        // with a non-rebasing token, in which case the amount deposited and the amount received will always be different
        // so we simply enforce that the amount received is equal to the amount attributed to the user

        // send caller their DS
        assetPair.ds.transfer(caller, dsAttributed);
        // repay flash loan
        assetPair.ct.transfer(msg.sender, dsAttributed);
    }

    function __afterFlashswapSell(
        ReserveState storage self,
        uint256 ctAmount,
        Id reserveId,
        uint256 dsId,
        address caller,
        uint256 raAttributed
    ) internal {
        AssetPair storage assetPair = self.ds[dsId];
        IERC20(assetPair.ds).safeIncreaseAllowance(_moduleCore, ctAmount);
        IERC20(assetPair.ct).safeIncreaseAllowance(_moduleCore, ctAmount);

        IPSMcore psm = IPSMcore(_moduleCore);

        (uint256 received,,) = psm.redeemRaWithCtDs(reserveId, ctAmount);

        // for rounding error and to satisfy uni v2 liquidity rules(it forces us to repay 1 wei higher to prevent liquidity stealing)
        uint256 repaymentAmount = received - raAttributed;

        Asset ra = assetPair.ra;

        assert(repaymentAmount + raAttributed >= received);

        // send caller their RA
        IERC20(ra).safeTransfer(caller, raAttributed);
        // repay flash loan
        IERC20(ra).safeTransfer(msg.sender, repaymentAmount);
    }
}
