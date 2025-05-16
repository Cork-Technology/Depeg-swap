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
 * @notice Abstract base contract for managing individual liquidation orders
 * @dev Provides common functionality for vault and Protected Unit liquidations.
 *      Designed to be deployed as minimal proxies (clones) to reduce gas costs.
 * @author Cork Protocol Team
 */
abstract contract ChildLiquidatorBase is OwnableUpgradeable {
    /**
     * @notice Details about the current liquidation order
     * @dev Stores information about which tokens are being traded and their amounts
     */
    Liquidator.Details public order;

    /// @notice The unique identifier for the CoW Protocol order
    bytes public orderUid;

    /// @notice The address that will receive the liquidation proceeds
    address public receiver;

    /// @notice Internal reference ID to track this liquidation
    bytes32 public refId;

    /// @notice Error thrown when a zero address is provided where an address is required
    error ZeroAddress();

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Ensures accessible by the main Liquidator contract only
     * @custom:reverts OnlyLiquidator if the caller is not the owner
     */
    modifier onlyLiquidator() {
        if (_msgSender() != owner()) {
            revert IErrors.OnlyLiquidator();
        }
        _;
    }

    /**
     * @notice Sets up the child liquidator with necessary information
     * @dev Initializes the contract and approves token transfers to the settlement contract
     * @param _liquidator Address of the main liquidator contract
     * @param _order Details about the tokens being traded
     * @param _orderUid CoW Protocol order identifier
     * @param _receiver Address that will receive the liquidation proceeds
     * @param _refId Internal reference ID for tracking
     * @custom:reverts ZeroAddress if _liquidator or _receiver is the zero address
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
 * @notice Specialized child liquidator for Protected Unit liquidations
 * @dev Manages the transfer of funds between the settlement contract and Protected Unit.
 *      Deployed as a minimal proxy (clone) by the main Liquidator contract.
 */
contract ProtectedUnitChildLiquidator is ChildLiquidatorBase {
    /**
     * @notice Transfers liquidation proceeds to the Protected Unit
     * @dev Moves both bought tokens and any leftover sell tokens by:
     *      1. Approving the Protected Unit to transfer the tokens
     *      2. Calling the Protected Unit's receiveFunds function
     * @return funds Amount of buy tokens transferred to the Protected Unit
     * @return leftover Amount of sell tokens that weren't used in the trade
     * @custom:reverts OnlyLiquidator if caller is not the main Liquidator contract
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
 * @notice Specialized child liquidator for vault liquidations
 * @dev Manages the transfer of funds between the settlement contract and vault.
 *      Deployed as a minimal proxy (clone) by the main Liquidator contract.
 */
contract VaultChildLiquidator is ChildLiquidatorBase {
    /**
     * @notice Transfers liquidation proceeds to the vault
     * @dev Moves both bought tokens and any leftover sell tokens by:
     *      1. Approving the vault to transfer the tokens
     *      2. Calling the appropriate vault functions for each token type
     * @param id The ID of the vault receiving the funds
     * @custom:reverts OnlyLiquidator if caller is not the main Liquidator contract
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
