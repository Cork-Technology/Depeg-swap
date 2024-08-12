// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../libraries/DsFlashSwap.sol";
import "../../libraries/MathHelper.sol";
import "../../libraries/Pair.sol";
import "../../interfaces/IDsFlashSwapRouter.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../../interfaces/uniswap-v2/callee.sol";
import "../../interfaces/uniswap-v2/RouterV2.sol";
import "../../libraries/uni-v2/UniswapV2Library.sol";
import "../../interfaces/IPSMcore.sol";

contract RouterState is
    IDsFlashSwapUtility,
    IDsFlashSwapCore,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IUniswapV2Callee
{
    using DsFlashSwaplibrary for ReserveState;
    using DsFlashSwaplibrary for AssetPair;

    constructor() {}

    IUniswapV2Router02 univ2Router;

    function initialize(
        address moduleCore,
        address _univ2Router
    ) external initializer notDelegated {
        __Ownable_init(moduleCore);
        __UUPSUpgradeable_init();

        univ2Router = IUniswapV2Router02(_univ2Router);
    }

    mapping(Id => ReserveState) reserves;

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner notDelegated {}

    function onNewIssuance(
        Id reserveId,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve,
        address ra,
        address ct
    ) external override onlyOwner {
        reserves[reserveId].onNewIssuance(
            dsId,
            ds,
            pair,
            initialReserve,
            ra,
            ct
        );

        emit NewIssuance(reserveId, dsId, ds, pair, initialReserve);
    }

    function getAmmReserve(
        Id id,
        uint256 dsId
    ) external view override returns (uint112 raReserve, uint112 ctReserve) {
        (raReserve, ctReserve) = reserves[id].getReserve(dsId);
    }

    function getLvReserve(
        Id id,
        uint256 dsId
    ) external view override returns (uint256 lvReserve) {
        return reserves[id].ds[dsId].reserve;
    }

    function getUniV2pair(
        Id id,
        uint256 dsId
    ) external view override returns (IUniswapV2Pair pair) {
        return reserves[id].getPair(dsId);
    }

    function emptyReserve(
        Id reserveId,
        uint256 dsId
    ) external override onlyOwner returns (uint256 amount) {
        amount = reserves[reserveId].emptyReserve(dsId, owner());
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePartial(
        Id reserveId,
        uint256 dsId,
        uint256 amount
    ) external override onlyOwner returns (uint256 reserve) {
        reserve = reserves[reserveId].emptyReservePartial(
            dsId,
            amount,
            owner()
        );
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function getCurrentPriceRatio(
        Id id,
        uint256 dsId
    )
        external
        view
        override
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        (raPriceRatio, ctPriceRatio) = reserves[id].getPriceRatio(dsId);
    }

    function addReserve(
        Id id,
        uint256 dsId,
        uint256 amount
    ) external override onlyOwner {
        reserves[id].addReserve(dsId, amount, owner());
        emit ReserveAdded(id, dsId, amount);
    }

    function getState(
        Id id
    ) internal view returns (ReserveState storage reserve) {
        return reserves[id];
    }

    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin
    ) external returns (uint256 amountOut) {
        // ReserveState storage self = reserves[reserveId];
        // AssetPair storage assetPair = self.ds[dsId];
        // assetPair.ra.transferFrom(msg.sender, address(this), amount);
        // // calculate the amount of DS tokens attributed
        // amountOut = ((amount * 1e18) / self.getCurrentDsPrice(dsId));
        // // calculate the amount of DS tokens that will be sold from LV reserve
        // uint256 amountSellFromReserve = amountOut -
        //     MathHelper.calculatePrecentageFee(
        //         self.reserveSellPressurePrecentage,
        //         amountOut
        //     );
        // // sell all tokens if the sell amount is higher than the available reserve
        // amountSellFromReserve = assetPair.reserve < amountSellFromReserve
        //     ? assetPair.reserve
        //     : amountSellFromReserve;
        // // sell the DS tokens from the reserve if there's any
        // if (amountSellFromReserve != 0) {
        //     // decrement reserve
        //     assetPair.reserve -= amountSellFromReserve;
        //     // sell the DS tokens from the reserve
        //     __swapDsforRa(assetPair, reserveId, dsId, amountSellFromReserve, 0);
        //     // recalculate the amount of DS tokens attributed, since we sold some from the reserve
        //     amountOut = (self.getCurrentDsPrice(dsId) * amount) / 1e18;
        // }
        // if (amountOut < amountOutMin) {
        //     revert InsufficientOutputAmount();
        // }
        // // trigger flash swaps and send the attributed DS tokens to the user
        // __flashSwap(
        //     assetPair,
        //     assetPair.pair,
        //     amount,
        //     0,
        //     dsId,
        //     reserveId,
        //     true,
        //     amountOut
        // );
        // emit RaSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    function previewSwapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 amountOut) {
        // ReserveState storage self = reserves[reserveId];
        // AssetPair storage assetPair = self.ds[dsId];
        // uint256 dsPrice = self.getCurrentDsPrice(dsId);
        // // calculate the amount of DS tokens attributed
        // amountOut = ((amount * 1e18) / dsPrice);
        // // calculate the amount of DS tokens that will be sold from LV reserve
        // uint256 amountSellFromReserve = amountOut -
        //     MathHelper.calculatePrecentageFee(
        //         self.reserveSellPressurePrecentage,
        //         amountOut
        //     );
        // // sell all tokens if the sell amount is higher than the available reserve
        // amountSellFromReserve = assetPair.reserve < amountSellFromReserve
        //     ? assetPair.reserve
        //     : amountSellFromReserve;
        // // sell the DS tokens from the reserve if there's any
        // if (amountSellFromReserve != 0) {
        //     // we borrow the same amount of CT tokens from the reserve
        //     uint256 ctSubstracted = amountSellFromReserve;
        //     // this the amount to repay the flash swaps
        //     uint256 raAdded = amountSellFromReserve -
        //         ((dsPrice * amountSellFromReserve) / 1e18);
        //     (uint112 raReserve, uint112 ctReserve, ) = assetPair
        //         .pair
        //         .getReserves();
        //     dsPrice = self.getCurrentDsPriceAfterSellDs(
        //         dsId,
        //         ctSubstracted,
        //         raReserve,
        //         ctReserve
        //     );
        //     amountOut = (dsPrice * amount) / 1e18;
        // }
    }

    function swapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin
    ) external returns (uint256 amountOut) {
        AssetPair storage assetPair = reserves[reserveId].ds[dsId];

        assetPair.ds.transferFrom(msg.sender, address(this), amount);

        amountOut = __swapDsforRa(
            assetPair,
            reserveId,
            dsId,
            amount,
            amountOutMin
        );

        emit DsSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    function __swapDsforRa(
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin
    ) internal returns (uint256 amountOut) {
        amountOut = assetPair.getAmountOut(amount);

        console.log("amountout", amountOut);

        if (amountOut < amountOutMin) {
            revert InsufficientOutputAmount();
        }

        __flashSwap(
            assetPair,
            assetPair.pair,
            0,
            amount,
            dsId,
            reserveId,
            false,
            amountOut
        );
    }

    function previewSwapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount
    ) external view returns (uint256 amountOut) {
        AssetPair storage assetPair = reserves[reserveId].ds[dsId];
        amountOut = assetPair.getAmountOut(amount);
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
        (, , uint256 amount0out, uint256 amount1out) = MinimalUniswapV2Library
            .sortTokensUnsafeWithAmount(
                address(assetPair.ra),
                address(assetPair.ct),
                raAmount,
                ctAmount
            );

        bytes memory data = abi.encode(
            reserveId,
            dsId,
            buyDs,
            msg.sender,
            extraData
        );

        univ2Pair.swap(amount0out, amount1out, address(this), data);
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        (
            Id reserveId,
            uint256 dsId,
            bool buyDs,
            address caller,
            uint256 extraData
        ) = abi.decode(data, (Id, uint256, bool, address, uint256));

        ReserveState storage self = reserves[reserveId];
        IUniswapV2Pair pair = self.getPair(dsId);

        assert(msg.sender == address(pair));
        assert(sender == address(this));

        uint256 amount = amount0 == 0 ? amount1 : amount0;

        if (buyDs) {
            __afterFlashswapBuy(
                self,
                amount,
                reserveId,
                dsId,
                caller,
                extraData
            );
        } else {
            __afterFlashswapSell(
                self,
                amount,
                reserveId,
                dsId,
                caller,
                extraData
            );
        }
    }

    function __afterFlashswapBuy(
        ReserveState storage self,
        uint256 raAmount,
        Id reserveId,
        uint256 dsId,
        address caller,
        uint256 dsAttributed
    ) internal {
        AssetPair storage assetPair = self.ds[dsId];
        assetPair.ra.approve(owner(), raAmount);

        IPSMcore psm = IPSMcore(owner());
        (uint256 received, ) = psm.depositPsm(reserveId, raAmount);
        // should be the same, we don't compare with the RA amount since we maybe dealing
        // with a non-rebasing token, in which case the amount deposited and the amount received will always be different
        // so we simply enforce that the amount received is equal to the amount attributed to the user
        assert(received == dsAttributed);

        // send caller their DS
        assetPair.ds.transfer(caller, dsAttributed);
        // repay flash loan
        assetPair.ds.transfer(msg.sender, received);
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

        (uint256 received, ) = psm.redeemRaWithCtDs(reserveId, ctAmount);

        // for rounding error and to satisfy uni v2 liquidity rules(it forces us to repay 1 wei higher to prevent liquidity stealing)
        uint256 repaymentAmount = received - raAttributed;

        Asset ra = assetPair.ra;

        assert(repaymentAmount + raAttributed >= received);

        // send caller their RA
        ra.transfer(caller, raAttributed);
        // repay flash loan
        ra.transfer(msg.sender, repaymentAmount);
    }
}
