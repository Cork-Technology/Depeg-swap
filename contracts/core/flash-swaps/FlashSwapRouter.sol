pragma solidity 0.8.24;

import {AssetPair, ReserveState, DsFlashSwaplibrary} from "../../libraries/DsFlashSwap.sol";
import {SwapperMathLibrary} from "../../libraries/DsSwapperMathLib.sol";
import {MathHelper} from "../../libraries/MathHelper.sol";
import {Id} from "../../libraries/Pair.sol";
import {IDsFlashSwapCore, IDsFlashSwapUtility} from "../../interfaces/IDsFlashSwapRouter.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IUniswapV2Callee} from "../../interfaces/uniswap-v2/callee.sol";
import {IUniswapV2Router02} from "../../interfaces/uniswap-v2/RouterV2.sol";
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
contract RouterState is IDsFlashSwapUtility, IDsFlashSwapCore, OwnableUpgradeable, UUPSUpgradeable, IUniswapV2Callee {
    using DsFlashSwaplibrary for ReserveState;
    using DsFlashSwaplibrary for AssetPair;
    using SafeERC20 for IERC20;

    IUniswapV2Router02 internal univ2Router;

    function initialize(address moduleCore, address _univ2Router) external initializer notDelegated {
        __Ownable_init(moduleCore);
        __UUPSUpgradeable_init();

        univ2Router = IUniswapV2Router02(_univ2Router);
    }

    mapping(Id => ReserveState) internal reserves;

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner notDelegated {}

    function onNewIssuance(
        Id reserveId,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve,
        address ra,
        address ct
    ) external override onlyOwner {
        reserves[reserveId].onNewIssuance(dsId, ds, pair, initialReserve, ra, ct);

        emit NewIssuance(reserveId, dsId, ds, pair, initialReserve);
    }

    function getAmmReserve(Id id, uint256 dsId) external view override returns (uint112 raReserve, uint112 ctReserve) {
        (raReserve, ctReserve) = reserves[id].getReserve(dsId);
    }

    function getLvReserve(Id id, uint256 dsId) external view override returns (uint256 lvReserve) {
        return reserves[id].ds[dsId].reserve;
    }

    function getUniV2pair(Id id, uint256 dsId) external view override returns (IUniswapV2Pair pair) {
        return reserves[id].getPair(dsId);
    }

    function emptyReserve(Id reserveId, uint256 dsId) external override onlyOwner returns (uint256 amount) {
        amount = reserves[reserveId].emptyReserve(dsId, owner());
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePartial(Id reserveId, uint256 dsId, uint256 amount)
        external
        override
        onlyOwner
        returns (uint256 reserve)
    {
        reserve = reserves[reserveId].emptyReservePartial(dsId, amount, owner());
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

    function addReserve(Id id, uint256 dsId, uint256 amount) external override onlyOwner {
        reserves[id].addReserve(dsId, amount, owner());
        emit ReserveAdded(id, dsId, amount);
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

        // calculate the amount of DS tokens attributed
        (amountOut, borrowedAmount,) = assetPair.getAmountOutBuyDS(amount);

        // calculate the amount of DS tokens that will be sold from LV reserve
        uint256 amountSellFromReserve =
            amountOut - MathHelper.calculatePrecentageFee(self.reserveSellPressurePrecentage, amountOut);

        // sell all tokens if the sell amount is higher than the available reserve
        amountSellFromReserve = assetPair.reserve < amountSellFromReserve ? assetPair.reserve : amountSellFromReserve;

        // sell the DS tokens from the reserve if there's any
        if (amountSellFromReserve != 0) {
            // decrement reserve
            assetPair.reserve -= amountSellFromReserve;

            // sell the DS tokens from the reserve and accrue value to LV holders
            uint256 vaultRa = __swapDsforRa(assetPair, reserveId, dsId, amountSellFromReserve, 0);
            IVault(owner()).provideLiquidityWithFlashSwapFee(reserveId, vaultRa);

            // recalculate the amount of DS tokens attributed, since we sold some from the reserve
            (amountOut, borrowedAmount,) = assetPair.getAmountOutBuyDS(amount);
        }

        if (amountOut < amountOutMin) {
            revert InsufficientOutputAmount();
        }

        // trigger flash swaps and send the attributed DS tokens to the user

        __flashSwap(assetPair, assetPair.pair, borrowedAmount, 0, dsId, reserveId, true, amountOut);
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
        bytes memory rawRaPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];
        if (!DsFlashSwaplibrary.isRAsupportsPermit(address(assetPair.ra))) {
            revert PermitNotSupported();
        }

        DepegSwapLibrary.permit(address(assetPair.ra), rawRaPermitSig, msg.sender, address(this), amount, deadline);
        IERC20(assetPair.ra).safeTransferFrom(msg.sender, address(this), amount);

        amountOut = _swapRaforDs(self, assetPair, reserveId, dsId, amount, amountOutMin);

        emit RaSwapped(reserveId, dsId, msg.sender, amount, amountOut);
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

        emit RaSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

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

        uint256 borrowedAmount;
        (amountOut, borrowedAmount,) = assetPair.getAmountOutBuyDS(amount);

        // calculate the amount of DS tokens that will be sold from LV reserve
        uint256 amountSellFromReserve =
            amountOut - MathHelper.calculatePrecentageFee(self.reserveSellPressurePrecentage, amountOut);

        // sell all tokens if the sell amount is higher than the available reserve
        amountSellFromReserve = assetPair.reserve < amountSellFromReserve ? assetPair.reserve : amountSellFromReserve;

        // sell the DS tokens from the reserve if there's any
        if (amountSellFromReserve != 0) {
            (uint112 raReserve, uint112 ctReserve) = assetPair.getReservesSorted();

            // we borrow the same amount of CT tokens from the reserve
            ctReserve -= uint112(amountSellFromReserve);

            (uint256 vaultRa, uint256 raAdded) = assetPair.getAmountOutSellDS(amountSellFromReserve);
            raReserve += uint112(raAdded);

            // emulate Vault way of adding liquidity using RA from selling DS reserve
            (, uint256 ratio) = self.tryGetPriceRatioAfterSellDs(dsId, amountSellFromReserve, raAdded);
            uint256 ctAdded;
            (raAdded, ctAdded) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(vaultRa, ratio);

            raReserve += uint112(raAdded);
            ctReserve += uint112(ctAdded);

            // update amountOut since we sold some from the reserve
            (, amountOut) = SwapperMathLibrary.getAmountOutDs(
                int256(uint256(raReserve)), int256(uint256(ctReserve)), int256(amount)
            );
        }
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
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        AssetPair storage assetPair = reserves[reserveId].ds[dsId];

        DepegSwapLibrary.permit(address(assetPair.ds), rawDsPermitSig, msg.sender, address(this), amount, deadline);
        assetPair.ds.transferFrom(msg.sender, address(this), amount);

        amountOut = __swapDsforRa(assetPair, reserveId, dsId, amount, amountOutMin);

        emit DsSwapped(reserveId, dsId, msg.sender, amount, amountOut);
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
        AssetPair storage assetPair = reserves[reserveId].ds[dsId];

        assetPair.ds.transferFrom(msg.sender, address(this), amount);

        amountOut = __swapDsforRa(assetPair, reserveId, dsId, amount, amountOutMin);

        emit DsSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    function __swapDsforRa(
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin
    ) internal returns (uint256 amountOut) {
        (amountOut,) = assetPair.getAmountOutSellDS(amount);

        if (amountOut < amountOutMin) {
            revert InsufficientOutputAmount();
        }

        __flashSwap(assetPair, assetPair.pair, 0, amount, dsId, reserveId, false, amountOut);
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
        (amountOut,) = assetPair.getAmountOutSellDS(amount);
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
        uint256 extraData
    ) internal {
        (,, uint256 amount0out, uint256 amount1out) = MinimalUniswapV2Library.sortTokensUnsafeWithAmount(
            address(assetPair.ra), address(assetPair.ct), raAmount, ctAmount
        );

        bytes memory data = abi.encode(reserveId, dsId, buyDs, msg.sender, extraData);

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
        assetPair.ra.approve(owner(), dsAttributed);

        IPSMcore psm = IPSMcore(owner());
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
        assetPair.ds.approve(owner(), ctAmount);
        assetPair.ct.approve(owner(), ctAmount);

        IPSMcore psm = IPSMcore(owner());

        (uint256 received,) = psm.redeemRaWithCtDs(reserveId, ctAmount);

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
