pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Liquidator, GPv2SettlementContract} from "./Liquidator.sol";
import {ILiquidator} from "../../../interfaces/ILiquidator.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
        if (msg.sender == owner()) {
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
