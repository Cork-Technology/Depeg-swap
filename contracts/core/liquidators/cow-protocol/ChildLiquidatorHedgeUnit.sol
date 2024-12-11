pragma solidity ^0.8.24;

import {ChildLiquidatorBase} from "./Foundation.sol";
import {Liquidator} from "./Liquidator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHedgeUnitLiquidation} from "./../../../interfaces/IHedgeUnitLiquidation.sol";
import {HedgeUnit} from "./../../assets/HedgeUnit.sol";
import "./../../../interfaces/IHedgeUnitLiquidation.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./../../../interfaces/IDsFlashSwapRouter.sol";

contract HedgeUnitChildLiquidator is ChildLiquidatorBase {
    function moveFunds() external onlyLiquidator {
        _moveFunds();
    }

    function _moveFunds() internal returns (uint256 funds, uint256 leftover) {
        // move buy token balance of this contract to vault, by approving the vault to transfer the funds
        funds = IERC20(order.buyToken).balanceOf(address(this));
        SafeERC20.forceApprove(IERC20(order.buyToken), receiver, funds);

        IHedgeUnitLiquidation(receiver).receiveFunds(funds, order.buyToken);

        // move leftover sell token balance of this contract to vault, by approving the vault to transfer the funds
        leftover = IERC20(order.sellToken).balanceOf(address(this));
        SafeERC20.forceApprove(IERC20(order.sellToken), receiver, leftover);

        IHedgeUnitLiquidation(receiver).receiveFunds(leftover, order.sellToken);
    }

    function moveFundsAndExecuteTrade(uint256 amountOutMin, IDsFlashSwapCore calldata params) external onlyLiquidator {
        (uint256 funds,) = _moveFunds();
        HedgeUnit(receiver).useFunds(funds, amountOutMin, params);
    }
}
