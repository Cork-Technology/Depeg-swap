// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {AssetPair, ReserveState, DsFlashSwaplibrary} from "../../libraries/DsFlashSwap.sol";
import {SwapperMathLibrary} from "../../libraries/DsSwapperMathLib.sol";
import {MathHelper} from "../../libraries/MathHelper.sol";
import {Id} from "../../libraries/Pair.sol";
import {IDsFlashSwapCore, IDsFlashSwapUtility} from "../../interfaces/IDsFlashSwapRouter.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IPSMcore} from "../../interfaces/IPSMcore.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {Asset} from "../assets/Asset.sol";
import {DepegSwapLibrary} from "../../libraries/DepegSwapLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICorkHook} from "../../interfaces/UniV4/IMinimalHook.sol";
import {AmmId, toAmmId} from "Cork-Hook/lib/State.sol";
import {CorkSwapCallback} from "Cork-Hook/interfaces/CorkSwapCallback.sol";
import {IErrors} from "./../../interfaces/IErrors.sol";
import {TransferHelper} from "./../../libraries/TransferHelper.sol";
import {ReturnDataSlotLib} from "./../../libraries/ReturnDataSlotLib.sol";
import {CorkConfig} from "../CorkConfig.sol";

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
    CorkSwapCallback
{
    using DsFlashSwaplibrary for ReserveState;
    using DsFlashSwaplibrary for AssetPair;
    using SafeERC20 for IERC20;

    bytes32 public constant MODULE_CORE = keccak256("MODULE_CORE");
    bytes32 public constant CONFIG = keccak256("CONFIG");

    // 30% max fee
    uint256 public constant MAX_DS_FEE = 30e18;

    address public _moduleCore;
    ICorkHook public hook;
    CorkConfig public config;
    mapping(Id => ReserveState) internal reserves;

    // this is here to prevent stuck funds, essentially it can happen that the reserve DS is so low but not empty,
    // when the router tries to sell it, the trade fails, preventing user from buying DS properly
    uint256 public constant RESERVE_MINIMUM_SELL_AMOUNT = 0.001 ether;

    struct CalculateAndSellDsParams {
        Id reserveId;
        uint256 dsId;
        uint256 raIn;
        uint256 dsOut;
    }

    struct SellDsParams {
        Id reserveId;
        uint256 dsId;
        uint256 amountSellFromReserve;
    }

    struct SellResult {
        uint256 amountOut;
        uint256 borrowedAmount;
        bool success;
    }

    struct CallbackData {
        bool buyDs;
        address caller;
        // CT or RA amount borrowed
        uint256 borrowed;
        // DS or RA amount provided
        uint256 provided;
        Id reserveId;
        uint256 dsId;
    }

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

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

    modifier autoClearReturnData() {
        _;
        ReturnDataSlotLib.clear(ReturnDataSlotLib.RETURN_SLOT_BUY);
        ReturnDataSlotLib.clear(ReturnDataSlotLib.RETURN_SLOT_SELL);
        ReturnDataSlotLib.clear(ReturnDataSlotLib.REFUNDED_SLOT);
        ReturnDataSlotLib.clear(ReturnDataSlotLib.DS_FEE_AMOUNT);
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _config) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONFIG, _config);
        config = CorkConfig(_config);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyDefaultAdmin {}

    /// @inheritdoc IDsFlashSwapCore
    function updateDiscountRateInDdays(Id id, uint256 discountRateInDays) external override onlyConfig {
        reserves[id].decayDiscountRateInDays = discountRateInDays;

        emit DiscountRateUpdated(id, discountRateInDays);
    }

    /// @inheritdoc IDsFlashSwapCore
    function updateGradualSaleStatus(Id id, bool status) external override onlyConfig {
        reserves[id].gradualSaleDisabled = status;

        emit GradualSaleStatusUpdated(id, status);
    }

    /// @inheritdoc IDsFlashSwapCore
    function updateDsExtraFeePercentage(Id id, uint256 newPercentage) external onlyConfig {
        if (newPercentage > MAX_DS_FEE) {
            revert InvalidFee();
        }
        reserves[id].dsExtraFeePercentage = newPercentage;

        emit DsFeeUpdated(id, newPercentage);
    }

    /// @inheritdoc IDsFlashSwapCore
    function updateDsExtraFeeTreasurySplitPercentage(Id id, uint256 newPercentage) external onlyConfig {
        reserves[id].dsExtraFeeTreasurySplitPercentage = newPercentage;

        emit DsFeeTreasuryPercentageUpdated(id, newPercentage);
    }

    /// @inheritdoc IDsFlashSwapUtility
    function getCurrentCumulativeHIYA(Id id) external view returns (uint256 hpaCummulative) {
        hpaCummulative = reserves[id].getCurrentCumulativeHIYA();
    }

    /// @inheritdoc IDsFlashSwapUtility
    function getCurrentEffectiveHIYA(Id id) external view returns (uint256 hpa) {
        hpa = reserves[id].getEffectiveHIYA();
    }

    /**
     * @notice Sets the module core address.
     * @dev This function can only be called by the default admin.
     * @param moduleCore The new module core address.
     */
    function setModuleCore(address moduleCore) external onlyDefaultAdmin {
        if (moduleCore == address(0)) {
            revert ZeroAddress();
        }
        _moduleCore = moduleCore;
        _grantRole(MODULE_CORE, moduleCore);
    }

    /// @notice IMPORTANT : REPURPOSED TO THRESHOLD. THE PERCENTAGE WILL BE CALCULATED DYNAMICALLY
    /// we can't really change the signature of this since the configuration contract is not upgradeable and depends on this signature
    /// @inheritdoc IDsFlashSwapCore
    function updateReserveSellPressurePercentage(Id id, uint256 newPercentage) external override onlyConfig {
        reserves[id].updateReserveSellPressurePercentageThreshold(newPercentage);

        emit ReserveSellPressurePercentageUpdated(id, newPercentage);
    }

    /**
     * @notice Sets the hook address.
     * @dev This function can only be called by the default admin.
     * @param _hook The new hook address.
     */
    function setHook(address _hook) external onlyDefaultAdmin {
        hook = ICorkHook(_hook);
    }

    /// @inheritdoc IDsFlashSwapCore
    function onNewIssuance(Id reserveId, uint256 dsId, address ds, address ra, address ct)
        external
        override
        onlyModuleCore
    {
        reserves[reserveId].onNewIssuance(dsId, ds, ra, ct);

        emit NewIssuance(reserveId, dsId, ds, AmmId.unwrap(toAmmId(ra, ct)));
    }

    /// @inheritdoc IDsFlashSwapCore
    function setDecayDiscountAndRolloverPeriodOnNewIssuance(
        Id reserveId,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) external override onlyModuleCore {
        ReserveState storage self = reserves[reserveId];
        self.decayDiscountRateInDays = decayDiscountRateInDays;
        self.rolloverEndInBlockNumber = block.number + rolloverPeriodInblocks;
    }

    /// @inheritdoc IDsFlashSwapUtility
    function getAmmReserve(Id id, uint256 dsId) external view override returns (uint256 raReserve, uint256 ctReserve) {
        (raReserve, ctReserve) = reserves[id].getReserve(dsId, hook);
    }

    /// @inheritdoc IDsFlashSwapUtility
    function getLvReserve(Id id, uint256 dsId) external view override returns (uint256 lvReserve) {
        return reserves[id].ds[dsId].lvReserve;
    }

    /// @inheritdoc IDsFlashSwapUtility
    function getPsmReserve(Id id, uint256 dsId) external view override returns (uint256 psmReserve) {
        return reserves[id].ds[dsId].psmReserve;
    }

    /// @inheritdoc IDsFlashSwapCore
    function emptyReserveLv(Id reserveId, uint256 dsId) external override onlyModuleCore returns (uint256 amount) {
        amount = reserves[reserveId].emptyReserveLv(dsId, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    /// @inheritdoc IDsFlashSwapCore
    function emptyReservePartialLv(Id reserveId, uint256 dsId, uint256 amount)
        external
        override
        onlyModuleCore
        returns (uint256 emptied)
    {
        emptied = reserves[reserveId].emptyReservePartialLv(dsId, amount, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    /// @inheritdoc IDsFlashSwapCore
    function emptyReservePsm(Id reserveId, uint256 dsId) external override onlyModuleCore returns (uint256 amount) {
        amount = reserves[reserveId].emptyReservePsm(dsId, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    /// @inheritdoc IDsFlashSwapCore
    function emptyReservePartialPsm(Id reserveId, uint256 dsId, uint256 amount)
        external
        override
        onlyModuleCore
        returns (uint256 emptied)
    {
        emptied = reserves[reserveId].emptyReservePartialPsm(dsId, amount, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    /// @inheritdoc IDsFlashSwapUtility
    function getCurrentPriceRatio(Id id, uint256 dsId)
        external
        view
        override
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        (raPriceRatio, ctPriceRatio) = reserves[id].getPriceRatio(dsId, hook);
    }

    /// @inheritdoc IDsFlashSwapCore
    function addReserveLv(Id id, uint256 dsId, uint256 amount) external override onlyModuleCore {
        reserves[id].addReserveLv(dsId, amount, _moduleCore);
        emit ReserveAdded(id, dsId, amount);
    }

    /// @inheritdoc IDsFlashSwapCore
    function addReservePsm(Id id, uint256 dsId, uint256 amount) external override onlyModuleCore {
        reserves[id].addReservePsm(dsId, amount, _moduleCore);
        emit ReserveAdded(id, dsId, amount);
    }

    /// will return that can't be filled from the reserve, this happens when the total reserve is less than the amount requested
    function _swapRaForDsViaRollover(Id reserveId, uint256 dsId, address user, uint256 amountRa)
        internal
        returns (uint256 raLeft, uint256 dsReceived)
    {
        // this means that we ignore and don't do rollover sale when it's first issuance or it's not rollover time, or no hiya(means no trade, unlikely but edge case)
        if (
            dsId == DsFlashSwaplibrary.FIRST_ISSUANCE || !reserves[reserveId].rolloverSale()
                || reserves[reserveId].hiya == 0
        ) {
            // noop and return back the full amountRa
            return (amountRa, 0);
        }

        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        // If there's no reserve, we will proceed without using rollover
        if (assetPair.lvReserve == 0 && assetPair.psmReserve == 0) {
            return (amountRa, 0);
        }

        amountRa = TransferHelper.tokenNativeDecimalsToFixed(amountRa, reserves[reserveId].ds[dsId].ra);

        uint256 lvProfit;
        uint256 psmProfit;
        uint256 lvReserveUsed;
        uint256 psmReserveUsed;

        (lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed) =
            SwapperMathLibrary.calculateRolloverSale(assetPair.lvReserve, assetPair.psmReserve, amountRa, self.hiya);

        amountRa = TransferHelper.fixedToTokenNativeDecimals(amountRa, assetPair.ra);
        raLeft = TransferHelper.fixedToTokenNativeDecimals(raLeft, assetPair.ra);

        assetPair.psmReserve = assetPair.psmReserve - psmReserveUsed;
        assetPair.lvReserve = assetPair.lvReserve - lvReserveUsed;

        // we first transfer and normalized the amount, we get back the actual normalized amount
        psmProfit = TransferHelper.transferNormalize(assetPair.ra, _moduleCore, psmProfit);
        lvProfit = TransferHelper.transferNormalize(assetPair.ra, _moduleCore, lvProfit);

        assert(psmProfit + lvProfit <= amountRa);

        // then use the profit
        IPSMcore(_moduleCore).psmAcceptFlashSwapProfit(reserveId, psmProfit);
        IVault(_moduleCore).lvAcceptRolloverProfit(reserveId, lvProfit);

        IERC20(assetPair.ds).safeTransfer(user, dsReceived);

        {
            uint256 raLeftNormalized = TransferHelper.fixedToTokenNativeDecimals(raLeft, assetPair.ra);
            emit RolloverSold(reserveId, dsId, user, dsReceived, raLeftNormalized);
        }
    }

    /**
     * @notice Returns the block number when the rollover sale ends for a given reserve.
     * @param reserveId The identifier of the reserve.
     * @return endInBlockNumber The block number when the rollover sale ends.
     */
    function rolloverSaleEnds(Id reserveId) external view returns (uint256 endInBlockNumber) {
        return reserves[reserveId].rolloverEndInBlockNumber;
    }

    function _swapRaforDs(
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        address user,
        IDsFlashSwapCore.BuyAprroxParams memory approxParams,
        IDsFlashSwapCore.OffchainGuess memory offchainGuess
    ) internal returns (uint256 borrow) {
        uint256 dsReceived;
        // try to swap the RA for DS via rollover, this will noop if the condition for rollover is not met
        (amount, dsReceived) = _swapRaForDsViaRollover(reserveId, dsId, user, amount);

        // increase the return data slot value with DS that the user got from rollover sale
        ReturnDataSlotLib.increase(ReturnDataSlotLib.RETURN_SLOT_BUY, dsReceived);

        // short circuit if all the swap is filled using rollover
        if (amount == 0) {
            return (0);
        }

        uint256 amountOut;

        if (offchainGuess.borrow == 0) {
            // calculate the amount of DS tokens attributed
            (amountOut, borrow) = getAmountOutBuyDs(assetPair, hook, approxParams, amount);
        } else {
            // we convert the amount to fixed point 18 decimals since, the amount out will be DS, and DS is always 18 decimals.
            amountOut = TransferHelper.tokenNativeDecimalsToFixed(offchainGuess.borrow + amount, assetPair.ra);
            borrow = offchainGuess.borrow;
        }

        // trigger flash swaps and send the attributed DS tokens to the user
        __flashSwap(assetPair, borrow, 0, dsId, reserveId, true, user, amount);
    }

    function getAmountOutBuyDs(
        AssetPair storage assetPair,
        ICorkHook hook,
        BuyAprroxParams memory approxParams,
        uint256 amount
    ) internal view returns (uint256 amountOut, uint256 borrowedAmount) {
        try assetPair.getAmountOutBuyDS(amount, hook, approxParams) returns (
            uint256 _amountOut, uint256 _borrowedAmount
        ) {
            amountOut = _amountOut;
            borrowedAmount = _borrowedAmount;
        } catch {
            revert IErrors.InvalidPoolStateOrNearExpired();
        }
    }

    function calculateAndSellDsReserve(
        ReserveState storage self,
        AssetPair storage assetPair,
        CalculateAndSellDsParams memory params
    ) internal returns (uint256 pressurePercentage) {
        uint256 amountSellFromReserve;

        // calculate the amount of DS tokens that will be sold from reserve
        (amountSellFromReserve, pressurePercentage) =
            calculateSellFromReserve(self, params.dsOut, params.dsId, params.raIn);

        if (amountSellFromReserve < RESERVE_MINIMUM_SELL_AMOUNT || self.gradualSaleDisabled) {
            return (0);
        }

        bool success = _sellDsReserve(assetPair, SellDsParams(params.reserveId, params.dsId, amountSellFromReserve));

        // we return 0 in case it fails
        pressurePercentage = success ? pressurePercentage : 0;
    }

    function calculateSellFromReserve(ReserveState storage self, uint256 amountOut, uint256 dsId, uint256 raProvided)
        internal
        view
        returns (uint256 amount, uint256 sellPressure)
    {
        AssetPair storage assetPair = self.ds[dsId];

        sellPressure = self.determineSellPressure(dsId, raProvided, amountOut);

        uint256 amountSellFromReserve = MathHelper.calculatePercentageFee(sellPressure, amountOut);

        uint256 lvReserve = assetPair.lvReserve;
        uint256 totalReserve = lvReserve + assetPair.psmReserve;

        // sell all tokens if the sell amount is higher than the available reserve
        amount = totalReserve < amountSellFromReserve ? totalReserve : amountSellFromReserve;
    }

    function _sellDsReserve(AssetPair storage assetPair, SellDsParams memory params) internal returns (bool success) {
        uint256 profitRa;

        // sell the DS tokens from the reserve and accrue value to LV holders
        // it's safe to transfer all profit to the module core since the profit for each PSM and LV is calculated separately and we invoke
        // the profit acceptance function for each of them
        //
        // this function can fail, if there's not enough CT liquidity to sell the DS tokens, in that case, we skip the selling part and let user buy the DS tokens
        (profitRa, success) =
            __swapDsforRa(assetPair, params.reserveId, params.dsId, params.amountSellFromReserve, 0, _moduleCore);

        if (success) {
            uint256 lvReserve = assetPair.lvReserve;
            uint256 totalReserve = lvReserve + assetPair.psmReserve;

            // calculate the amount of DS tokens that will be sold from both reserve
            uint256 lvReserveUsed = lvReserve * params.amountSellFromReserve * 1e18 / (totalReserve) / 1e18;

            // decrement reserve
            assetPair.lvReserve -= lvReserveUsed;
            assetPair.psmReserve -= params.amountSellFromReserve - lvReserveUsed;

            // calculate the profit of the liquidity vault
            uint256 vaultProfit = profitRa * lvReserveUsed / params.amountSellFromReserve;

            // send profit to the vault
            IVault(_moduleCore).provideLiquidityWithFlashSwapFee(params.reserveId, vaultProfit);
            // send profit to the PSM
            IPSMcore(_moduleCore).psmAcceptFlashSwapProfit(params.reserveId, profitRa - vaultProfit);
        }
    }

    /**
     * @notice Executes a swap from RA to DS tokens.
     * @dev This function performs a flash swap, requiring a valid signature and deadline.
     * @param reserveId The ID of the reserve for RA:PA market in modulecore.
     * @param dsId The ID of the DS token to receive.
     * @param amount The amount of RA tokens to swap.
     * @param amountOutMin The minimum amount of DS tokens to receive.
     * @param rawRaPermitSig The raw signature for the RA permit.
     * @param deadline The deadline by which the swap must be completed.
     * @param params Additional parameters for the swap.
     * @param offchainGuess Offchain data used for the swap.
     * @return result The result of the swap, including amounts and other details.
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes calldata rawRaPermitSig,
        uint256 deadline,
        BuyAprroxParams calldata params,
        OffchainGuess calldata offchainGuess
    ) external autoClearReturnData returns (SwapRaForDsReturn memory result) {
        if (rawRaPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        if (!DsFlashSwaplibrary.isRAsupportsPermit(address(assetPair.ra))) {
            revert PermitNotSupported();
        }

        DepegSwapLibrary.permitForRA(address(assetPair.ra), rawRaPermitSig, msg.sender, address(this), amount, deadline);

        result = _swapRaForDsTopLevel(reserveId, dsId, amount, amountOutMin, params, offchainGuess);
    }

    function _swapRaForDsTopLevel(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        BuyAprroxParams calldata params,
        OffchainGuess calldata offchainGuess
    ) internal returns (SwapRaForDsReturn memory result) {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        IERC20(assetPair.ra).safeTransferFrom(msg.sender, address(this), amount);

        result.borrow = _swapRaforDs(assetPair, reserveId, dsId, amount, msg.sender, params, offchainGuess);

        result.amountOut = ReturnDataSlotLib.get(ReturnDataSlotLib.RETURN_SLOT_BUY);

        // slippage protection, revert if the amount of DS tokens received is less than the minimum amount
        if (result.amountOut < amountOutMin) {
            revert InsufficientOutputAmountForSwap();
        }

        result.ctRefunded = ReturnDataSlotLib.get(ReturnDataSlotLib.REFUNDED_SLOT);
        result.fee = ReturnDataSlotLib.get(ReturnDataSlotLib.DS_FEE_AMOUNT);

        uint256 raInFixed = TransferHelper.tokenNativeDecimalsToFixed(amount, assetPair.ra);

        result.reserveSellPressure = calculateAndSellDsReserve(
            self, assetPair, CalculateAndSellDsParams(reserveId, dsId, raInFixed, result.amountOut)
        );

        self.recalculateHIYA(dsId, raInFixed, result.amountOut);

        emit RaSwapped(
            reserveId,
            dsId,
            msg.sender,
            amount,
            result.amountOut,
            result.ctRefunded,
            result.fee,
            0,
            result.reserveSellPressure
        );
    }

    /**
     * @notice Executes a swap from RA to DS tokens.
     * @dev This function performs a flash swap, requiring a valid signature and deadline.
     * @param reserveId The ID of the reserve for RA:PA market in modulecore.
     * @param dsId The ID of the DS token to receive.
     * @param amount The amount of RA tokens to swap.
     * @param amountOutMin The minimum amount of DS tokens to receive.
     * @param params Additional parameters for the swap.
     * @param offchainGuess Offchain data used for the swap.
     * @return result The result of the swap, including amounts and other details.
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        BuyAprroxParams calldata params,
        OffchainGuess calldata offchainGuess
    ) external autoClearReturnData returns (SwapRaForDsReturn memory result) {
        result = _swapRaForDsTopLevel(reserveId, dsId, amount, amountOutMin, params, offchainGuess);
    }

    /// @inheritdoc IDsFlashSwapCore
    function isRolloverSale(Id id) external view returns (bool) {
        return reserves[id].rolloverSale();
    }

    /**
     * @notice Swaps specified amount of DS tokens for RA tokens
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this.
     * @param rawDsPermitSig the permit signature for DS token
     * @param deadline the deadline for the permit signature
     * @return amountOut amount of RA that's received
     * @dev Reverts if the actual amount is less than `amountOutMin`
     */
    function swapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes calldata rawDsPermitSig,
        uint256 deadline
    ) external autoClearReturnData returns (uint256 amountOut) {
        if (rawDsPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        DepegSwapLibrary.permit(
            address(assetPair.ds), rawDsPermitSig, msg.sender, address(this), amount, deadline, "swapDsforRa"
        );

        amountOut = _swapDsforRaTopLevel(reserveId, dsId, amount, amountOutMin);
    }

    function _swapDsforRaTopLevel(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        internal
        returns (uint256 amountOut)
    {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        assetPair.ds.transferFrom(msg.sender, address(this), amount);

        (, bool success) = __swapDsforRa(assetPair, reserveId, dsId, amount, amountOutMin, msg.sender);

        if (!success) {
            revert IErrors.InsufficientLiquidityForSwap();
        }

        amountOut = ReturnDataSlotLib.get(ReturnDataSlotLib.RETURN_SLOT_SELL);

        self.recalculateHIYA(dsId, TransferHelper.tokenNativeDecimalsToFixed(amountOut, assetPair.ra), amount);

        emit DsSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    /**
     * @notice Swaps specified amount of DS tokens for RA tokens
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this.
     * @return amountOut amount of RA that's received
     * @dev Reverts if the actual amount is less than `amountOutMin`
     */
    function swapDsforRa(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        autoClearReturnData
        returns (uint256 amountOut)
    {
        amountOut = _swapDsforRaTopLevel(reserveId, dsId, amount, amountOutMin);
    }

    function __swapDsforRa(
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address caller
    ) internal returns (uint256 amountOut, bool success) {
        try assetPair.getAmountOutSellDS(amount, hook) returns (uint256 _amountOut, uint256, bool _success) {
            amountOut = _amountOut;
            success = _success;
        } catch {
            return (0, false);
        }

        if (!success) {
            return (amountOut, success);
        }

        if (amountOut < amountOutMin) {
            revert InsufficientOutputAmountForSwap();
        }

        __flashSwap(assetPair, 0, amount, dsId, reserveId, false, caller, amount);
    }

    function __flashSwap(
        AssetPair storage assetPair,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 dsId,
        Id reserveId,
        bool buyDs,
        address caller,
        // DS or RA amount provided
        uint256 provided
    ) internal {
        uint256 borrowed = buyDs ? raAmount : ctAmount;
        CallbackData memory callbackData = CallbackData(buyDs, caller, borrowed, provided, reserveId, dsId);

        bytes memory data = abi.encode(callbackData);

        hook.swap(address(assetPair.ra), address(assetPair.ct), raAmount, ctAmount, data);
    }

    /**
     * @notice Executes a callback function during a flash swap.
     * @dev This function is called by the pool manager during a flash swap to handle the callback logic.
     * @param sender The address of the entity initiating the flash swap.
     * @param data Encoded data containing callback information.
     * @param paymentAmount The amount of tokens to be paid back to the pool.
     * @param paymentToken The address of the token to be paid back.
     * @param poolManager The address of the pool manager handling the flash swap.
     */
    function CorkCall(
        address sender,
        bytes calldata data,
        uint256 paymentAmount,
        address paymentToken,
        address poolManager
    ) external {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        ReserveState storage self = reserves[callbackData.reserveId];

        {
            // make sure only hook and forwarder can call this function
            assert(msg.sender == address(hook) || msg.sender == address(hook.getForwarder()));
            assert(sender == address(this));
        }

        if (callbackData.buyDs) {
            assert(paymentToken == address(self.ds[callbackData.dsId].ct));

            __afterFlashswapBuy(
                self,
                callbackData.reserveId,
                callbackData.dsId,
                callbackData.caller,
                callbackData.provided,
                callbackData.borrowed,
                poolManager,
                paymentAmount
            );
        } else {
            assert(paymentToken == address(self.ds[callbackData.dsId].ra));

            // same as borrowed since we're redeeming the same number of DS tokens with CT
            __afterFlashswapSell(
                self,
                callbackData.borrowed,
                callbackData.reserveId,
                callbackData.dsId,
                callbackData.caller,
                poolManager,
                paymentAmount
            );
        }
    }

    function __afterFlashswapBuy(
        ReserveState storage self,
        Id reserveId,
        uint256 dsId,
        address caller,
        uint256 provided,
        uint256 borrowed,
        address poolManager,
        uint256 actualRepaymentAmount
    ) internal {
        AssetPair storage assetPair = self.ds[dsId];

        uint256 deposited = provided + borrowed;

        IERC20(assetPair.ra).safeIncreaseAllowance(_moduleCore, deposited);

        IPSMcore psm = IPSMcore(_moduleCore);
        (uint256 received,) = psm.depositPsm(reserveId, deposited);

        // slither-disable-next-line uninitialized-local
        uint256 repaymentAmount;
        {
            // slither-disable-next-line uninitialized-local
            uint256 refunded;

            // not enough liquidity
            if (actualRepaymentAmount > received) {
                revert IErrors.InsufficientLiquidityForSwap();
            } else {
                refunded = received - actualRepaymentAmount;
                repaymentAmount = actualRepaymentAmount;
            }

            if (refunded > 0) {
                // refund the user with extra ct
                assetPair.ct.transfer(caller, refunded);
            }

            ReturnDataSlotLib.increase(ReturnDataSlotLib.REFUNDED_SLOT, refunded);
        }

        // send caller their DS
        assetPair.ds.transfer(caller, received);
        // repay flash loan
        assetPair.ct.transfer(poolManager, repaymentAmount);

        // set the return data slot
        ReturnDataSlotLib.increase(ReturnDataSlotLib.RETURN_SLOT_BUY, received);
    }

    function __afterFlashswapSell(
        ReserveState storage self,
        uint256 ctAmount,
        Id reserveId,
        uint256 dsId,
        address caller,
        address poolManager,
        uint256 actualRepaymentAmount
    ) internal {
        AssetPair storage assetPair = self.ds[dsId];

        IERC20(address(assetPair.ds)).safeIncreaseAllowance(_moduleCore, ctAmount);
        IERC20(address(assetPair.ct)).safeIncreaseAllowance(_moduleCore, ctAmount);

        IPSMcore psm = IPSMcore(_moduleCore);

        uint256 received = psm.returnRaWithCtDs(reserveId, ctAmount);

        Asset ra = assetPair.ra;

        if (actualRepaymentAmount > received) {
            revert IErrors.InsufficientLiquidityForSwap();
        }

        received = received - actualRepaymentAmount;

        // send caller their RA
        IERC20(ra).safeTransfer(caller, received);
        // repay flash loan
        IERC20(ra).safeTransfer(poolManager, actualRepaymentAmount);

        ReturnDataSlotLib.increase(ReturnDataSlotLib.RETURN_SLOT_SELL, received);
    }
}
