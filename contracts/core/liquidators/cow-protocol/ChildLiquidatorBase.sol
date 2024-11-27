pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Liquidator.sol";

abstract contract ChildLiquidatorBase is OwnableUpgradeable {
    Liquidator.Details public order;

    constructor() {
        _disableInitializers();
    }

    modifier onlyLiquidator() {
        if (msg.sender == owner()) {
            // revert Liquidator.OnlyLiquidator();
        }
        _;
    }

    function initialize(Liquidator _liquidator, Liquidator.Details memory _order) external initializer {
        __Ownable_init(address(_liquidator));
        order = _order;
    }

    function _approveSettlement() internal {
        // Liquidator(address(owner())).settlement().setPreSignature(order.orderUid, true);
    }
}
