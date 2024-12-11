pragma solidity ^0.8.24;

import {ChildLiquidatorBase} from "./Foundation.sol";
import {Liquidator} from "./Liquidator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultLiquidation} from "./../../../interfaces/IVaultLiquidation.sol";
import "./../../../interfaces/IVaultLiquidation.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VaultChildLiquidator is ChildLiquidatorBase {
    function moveFunds(Id id) external onlyLiquidator {
        // move buy token balance of this contract to vault, by approving the vault to transfer the funds
        uint256 balance = IERC20(order.buyToken).balanceOf(address(this));
        SafeERC20.forceApprove(IERC20(order.buyToken), receiver, balance);

        IVaultLiquidation(receiver).receiveTradeExecuctionResultFunds(id, balance);

        // move leftover sell token balance of this contract to vault, by approving the vault to transfer the funds
        balance = IERC20(order.sellToken).balanceOf(address(this));
        SafeERC20.forceApprove(IERC20(order.sellToken), receiver, balance);

        IVaultLiquidation(receiver).receiveLeftoverFunds(id, balance);
    }
}
