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

/**
 * @title Child Liquidator Base Contract
 * @notice Base contract for handling individual liquidation orders
 * @dev Abstract contract that provides common functionality for vault and Protected Unit liquidations
 */
abstract contract ChildLiquidatorBase is OwnableUpgradeable {
    /**
     * @notice Details about the current liquidation order
     * @dev Stores information about which tokens are being traded
     */
    Liquidator.Details public order;

    /**
     * @notice The unique identifier for the CoW Protocol order
     */
    bytes public orderUid;

    /**
     * @notice The address that will receive the liquidation proceeds
     */
    address public receiver;

    /**
     * @notice Internal reference ID to track this liquidation
     */
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

    /**
     * @notice Sets up the child liquidator with necessary information
     * @param _liquidator Address of the main liquidator contract
     * @param _order Details about the tokens being traded
     * @param _orderUid CoW Protocol order identifier
     * @param _receiver Address that will receive the liquidation proceeds
     * @param _refId Internal reference ID for tracking
     * @dev Initializes the contract and approves token transfers
     */
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

    /**
     * @notice Approves the CoW Protocol settlement contract to use tokens
     * @dev Sets up permissions for the settlement contract to execute trades
     */
    function _approveSettlement() internal {
        IGPv2SettlementContract settlement = Liquidator(address(owner())).SETTLEMENT();

        settlement.setPreSignature(orderUid, true);

        SafeERC20.safeIncreaseAllowance(IERC20(order.sellToken), address(settlement), order.sellAmount);
    }
}

/**
 * @title Protected Unit Child Liquidator
 * @notice Handles individual liquidation orders for Protected Units
 * @dev Manages the movement of funds during Protected Unit liquidations
 */
contract ProtectedUnitChildLiquidator is ChildLiquidatorBase {
    /**
     * @notice Transfers liquidation proceeds to the Protected Unit
     * @dev Moves both bought tokens and any leftover sell tokens
     * @return funds Amount of buy tokens transferred
     * @return leftover Amount of sell tokens that weren't used
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

/**
 * @title Vault Child Liquidator
 * @notice Handles individual liquidation orders for vaults
 * @dev Manages the movement of funds during vault liquidations
 */
contract VaultChildLiquidator is ChildLiquidatorBase {
    /**
     * @notice Transfers liquidation proceeds to the vault
     * @param id The ID of the vault receiving the funds
     * @dev Moves both bought tokens and any leftover sell tokens
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
