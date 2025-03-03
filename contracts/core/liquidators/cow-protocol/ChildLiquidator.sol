// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Liquidator, IGPv2SettlementContract} from "./Liquidator.sol";
import {IErrors} from "../../../interfaces/IErrors.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProtectedUnitLiquidation} from "./../../assets/ProtectedUnit.sol";
import {IVaultLiquidation} from "./../../../interfaces/IVaultLiquidation.sol";
import {Id} from "../../../libraries/Pair.sol";

// all contracts are here, since it wont work when we separated it. keep going into preceding imports issue

abstract contract ChildLiquidatorBase is OwnableUpgradeable {
    Liquidator.Details public order;
    bytes public orderUid;
    address public receiver;
    bytes32 public refId;

    error NotImplemented();
    error ZeroAddress();

    constructor() {
        _disableInitializers();
    }

    modifier onlyLiquidator() {
        if (msg.sender != owner()) {
            revert IErrors.OnlyLiquidator();
        }
        _;
    }

    function initialize(
        Liquidator _liquidator,
        Liquidator.Details calldata _order,
        bytes calldata _orderUid,
        address _receiver,
        bytes32 _refId
    ) external initializer {
        if (address(_liquidator) == address(0) || _receiver == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init(address(_liquidator));
        order = _order;
        orderUid = _orderUid;
        receiver = _receiver;
        refId = _refId;

        _approveSettlement();
    }

    function _approveSettlement() internal {
        IGPv2SettlementContract settlement = Liquidator(address(owner())).SETTLEMENT();

        settlement.setPreSignature(orderUid, true);

        SafeERC20.safeIncreaseAllowance(IERC20(order.sellToken), address(settlement), order.sellAmount);
    }
}

contract ProtectedUnitChildLiquidator is ChildLiquidatorBase {
    /**
     * @notice Moves the funds from this contract to the vault.
     * @dev This function transfers the buy token and sell token balances of this contract to the vault by approving the vault to transfer the funds.
     * @return funds The amount of buy token funds moved to the vault.
     * @return leftover The amount of sell token leftover moved to the vault.
     */
    function moveFunds() external onlyLiquidator returns (uint256 funds, uint256 leftover) {
        // move buy token balance of this contract to vault, by approving the vault to transfer the funds
        funds = IERC20(order.buyToken).balanceOf(address(this));
        SafeERC20.safeIncreaseAllowance(IERC20(order.buyToken), receiver, funds);

        IProtectedUnitLiquidation(receiver).receiveFunds(funds, order.buyToken);

        // move leftover sell token balance of this contract to vault, by approving the vault to transfer the funds
        leftover = IERC20(order.sellToken).balanceOf(address(this));
        SafeERC20.safeIncreaseAllowance(IERC20(order.sellToken), receiver, leftover);

        IProtectedUnitLiquidation(receiver).receiveFunds(leftover, order.sellToken);
    }
}

contract VaultChildLiquidator is ChildLiquidatorBase {
    /**
     * @notice Moves the funds associated with a given order ID to the vault.
     * @dev This function transfers the buy token and leftover sell token balances of this contract to the vault.
     * It approves the vault to transfer the funds before calling the vault's functions to receive the funds.
     * @param id The ID of the order whose funds are being moved.
     */
    function moveFunds(Id id) external onlyLiquidator {
        // move buy token balance of this contract to vault, by approving the vault to transfer the funds
        uint256 balance = IERC20(order.buyToken).balanceOf(address(this));
        SafeERC20.safeIncreaseAllowance(IERC20(order.buyToken), receiver, balance);

        IVaultLiquidation(receiver).receiveTradeExecuctionResultFunds(id, balance);

        // move leftover sell token balance of this contract to vault, by approving the vault to transfer the funds
        balance = IERC20(order.sellToken).balanceOf(address(this));
        SafeERC20.safeIncreaseAllowance(IERC20(order.sellToken), receiver, balance);

        IVaultLiquidation(receiver).receiveLeftoverFunds(id, balance);
    }
}
