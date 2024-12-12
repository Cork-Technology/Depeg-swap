pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Liquidator, GPv2SettlementContract} from "./Liquidator.sol";
import {ILiquidator} from "../../../interfaces/ILiquidator.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDsFlashSwapCore} from "./../../../interfaces/IDsFlashSwapRouter.sol";
import {HedgeUnit, IHedgeUnitLiquidation} from "./../../assets/HedgeUnit.sol";
import {IVaultLiquidation} from "./../../../interfaces/IVaultLiquidation.sol";
import {Id} from "../../../libraries/Pair.sol";

// all contracts are here, since it wont work when we separated it. keep going into preceding imports issue

abstract contract ChildLiquidatorBase is OwnableUpgradeable {
    Liquidator.Details public order;
    bytes public orderUid;
    address public receiver;
    bytes32 public refId;

    error NotImplemented();

    constructor() {
        _disableInitializers();
    }

    modifier onlyLiquidator() {
        if (msg.sender != owner()) {
            revert ILiquidator.OnlyLiquidator();
        }
        _;
    }

    function initialize(
        Liquidator _liquidator,
        Liquidator.Details memory _order,
        bytes memory _orderUid,
        address _receiver,
        bytes32 _refId
    ) external initializer {
        __Ownable_init(address(_liquidator));
        order = _order;
        orderUid = _orderUid;
        receiver = _receiver;
        refId = _refId;

        _approveSettlement();
    }

    function _approveSettlement() internal {
        GPv2SettlementContract settlement = Liquidator(address(owner())).settlement();

        settlement.setPreSignature(orderUid, true);

        SafeERC20.forceApprove(IERC20(order.sellToken), address(settlement), order.sellAmount);
    }
}

contract HedgeUnitChildLiquidator is ChildLiquidatorBase {
    function moveFunds() external onlyLiquidator returns (uint256 funds, uint256 leftover) {
        // move buy token balance of this contract to vault, by approving the vault to transfer the funds
        funds = IERC20(order.buyToken).balanceOf(address(this));
        SafeERC20.forceApprove(IERC20(order.buyToken), receiver, funds);

        IHedgeUnitLiquidation(receiver).receiveFunds(funds, order.buyToken);

        // move leftover sell token balance of this contract to vault, by approving the vault to transfer the funds
        leftover = IERC20(order.sellToken).balanceOf(address(this));
        SafeERC20.forceApprove(IERC20(order.sellToken), receiver, leftover);

        IHedgeUnitLiquidation(receiver).receiveFunds(leftover, order.sellToken);
    }
}

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
