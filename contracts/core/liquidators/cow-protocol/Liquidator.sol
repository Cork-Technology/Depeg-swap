// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidator} from "../../../interfaces/ILiquidator.sol";
import {IErrors} from "../../../interfaces/IErrors.sol";
import {IVaultLiquidation} from "./../../../interfaces/IVaultLiquidation.sol";
import {Id} from "./../../../libraries/Pair.sol";
import {CorkConfig} from "./../../CorkConfig.sol";
import {VaultChildLiquidator, ProtectedUnitChildLiquidator} from "./ChildLiquidator.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ProtectedUnit} from "./../../assets/ProtectedUnit.sol";
import {IProtectedUnitLiquidation} from "./../../../interfaces/IProtectedUnitLiquidation.sol";
import {IDsFlashSwapCore} from "./../../../interfaces/IDsFlashSwapRouter.sol";

/**
 * @notice Interface for interacting with CoW Protocol's settlement contract
 * @dev Used to set pre-signatures for orders in the CoW Protocol
 */
interface IGPv2SettlementContract {
    function setPreSignature(bytes calldata orderUid, bool signed) external;
}

/**
 * @title CoW Protocol Liquidator
 * @notice Manages liquidations of vaults and Protected Units through CoW Protocol
 * @dev Handles the creation and completion of liquidation orders on CoW Protocol.
 * @author Cork Protocol Team
 */
contract Liquidator is ILiquidator {
    using SafeERC20 for IERC20;

    /**
     * @notice Details of a liquidation order's tokens and amounts
     * @param sellToken Address of the token being sold in the liquidation
     * @param sellAmount Amount of the token to sell
     * @param buyToken Address of the token to receive from the liquidation
     */
    struct Details {
        address sellToken;
        uint256 sellAmount;
        address buyToken;
    }

    /**
     * @notice Full order information including liquidator and receiver details
     * @param details The token and amount details of the order
     * @param liquidator Address of the child liquidator contract handling this order
     * @param vaultId Unique ID of the vault being liquidated (empty for Protected Unit liquidations)
     * @param receiver Address that will receive the proceeds of the liquidation
     */
    struct Orders {
        Details details;
        address liquidator;
        // if not present then it's protected unit
        Id vaultId;
        address receiver;
    }

    /**
     * @notice Reference to the CoW Protocol settlement contract
     * @dev Used to interact with CoW Protocol for order settlement
     */
    IGPv2SettlementContract public immutable SETTLEMENT;

    address public immutable CONFIG;

    /**
     * @notice Address of the hook trampoline contract
     * @dev Used to interact with CoW Protocol hooks
     */
    address public immutable HOOK_TRAMPOLINE;

    /**
     * @notice Address of the base vault liquidator contract for cloning
     * @dev Used as a template for creating new vault liquidator instances
     */
    address public immutable VAULT_LIQUIDATOR_BASE;

    /**
     * @notice Address of the base Protected Unit liquidator contract for cloning
     * @dev Used as a template for creating new Protected Unit liquidator instances
     */
    address public immutable PROTECTED_UNIT_LIQUIDATOR_BASE;
    address public immutable MODULE_CORE;

    /// @notice Storage for active liquidation orders
    mapping(bytes32 => Orders) internal orderCalls;

    /**
     * @notice Ensures function access only to the hook trampoline contract
     * @custom:reverts OnlyTrampoline if caller is not the HOOK_TRAMPOLINE
     */
    modifier onlyTrampoline() {
        if (msg.sender != HOOK_TRAMPOLINE) {
            revert IErrors.OnlyTrampoline();
        }
        _;
    }

    /**
     * @notice Ensures function access only to authorized liquidators
     * @custom:reverts OnlyLiquidator if caller is not authorized
     */
    modifier onlyLiquidator() {
        if (!CorkConfig(CONFIG).isTrustedLiquidationExecutor(address(this), msg.sender)) {
            revert IErrors.OnlyLiquidator();
        }
        _;
    }

    /**
     * @notice Sets up the liquidator with required contract addresses
     * @param _config Address of the Cork Config contract
     * @param _hookTrampoline Address of the hook trampoline contract from CoW Protocol
     * @param _settlementContract Address of the CoW Protocol settlement contract
     * @param _moduleCore Address of the Module Core contract
     * @custom:reverts ZeroAddress if any provided address is zero
     */
    constructor(address _config, address _hookTrampoline, address _settlementContract, address _moduleCore) {
        if (
            _config == address(0) || _hookTrampoline == address(0) || _settlementContract == address(0)
                || _moduleCore == address(0)
        ) {
            revert IErrors.ZeroAddress();
        }
        SETTLEMENT = IGPv2SettlementContract(_settlementContract);
        CONFIG = _config;
        HOOK_TRAMPOLINE = _hookTrampoline;
        VAULT_LIQUIDATOR_BASE = address(new VaultChildLiquidator());
        PROTECTED_UNIT_LIQUIDATOR_BASE = address(new ProtectedUnitChildLiquidator());
        MODULE_CORE = _moduleCore;
    }

    /**
     * @notice Gets the address that will receive funds from a vault liquidation
     * @dev Deterministically generates the address using the CREATE2 opcode via Clones
     * @param refId A unique reference ID for this liquidation
     * @return receiver The address where liquidated funds will be sent
     */
    function fetchVaultReceiver(bytes32 refId) external returns (address receiver) {
        receiver = Clones.predictDeterministicAddress(VAULT_LIQUIDATOR_BASE, refId, address(this));
    }

    /**
     * @notice Gets the address that will receive funds from a Protected Unit liquidation
     * @dev Deterministically generates the address using the CREATE2 opcode via Clones
     * @param refId A unique reference ID for this liquidation
     * @return receiver The address where liquidated funds will be sent
     */
    function fetchProtectedUnitReceiver(bytes32 refId) external returns (address receiver) {
        receiver = Clones.predictDeterministicAddress(PROTECTED_UNIT_LIQUIDATOR_BASE, refId, address(this));
    }

    function _initializeVaultLiquidator(bytes32 refId, Details memory order, bytes memory orderUid)
        internal
        returns (address liquidator)
    {
        liquidator = Clones.cloneDeterministic(VAULT_LIQUIDATOR_BASE, refId);
        VaultChildLiquidator(liquidator).initialize(this, order, orderUid, MODULE_CORE, refId);
    }

    function _initializeProtectedUnitLiquidator(
        bytes32 refId,
        Details memory order,
        bytes memory orderUid,
        address protectedUnit
    ) internal returns (address liquidator) {
        liquidator = Clones.cloneDeterministic(PROTECTED_UNIT_LIQUIDATOR_BASE, refId);
        ProtectedUnitChildLiquidator(liquidator).initialize(this, order, orderUid, protectedUnit, refId);
    }

    function _moveVaultFunds(Details memory details, Id id, address liquidator) internal {
        IVaultLiquidation(MODULE_CORE).requestLiquidationFunds(id, details.sellAmount);

        SafeERC20.safeTransfer(IERC20(details.sellToken), liquidator, details.sellAmount);
    }

    function _moveProtectedUnitFunds(Details memory details, address protectedUnit, address liquidator) internal {
        IProtectedUnitLiquidation(protectedUnit).requestLiquidationFunds(
            details.sellAmount, details.sellToken, liquidator
        );

        SafeERC20.safeTransfer(IERC20(details.sellToken), liquidator, details.sellAmount);
    }

    /**
     * @notice Creates a new order to liquidate assets from a vault
     * @dev Sets up a child liquidator and records order details for tracking
     * @param params The parameters for the liquidation:
     *        - sellToken: Which token to sell
     *        - sellAmount: How many tokens to sell
     *        - buyToken: Which token to buy
     *        - internalRefId: Unique identifier for tracking
     *        - orderUid: CoW Protocol order identifier
     *        - vaultId: ID of the vault being liquidated
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If requesting or transferring funds fails
     * @custom:emits OrderSubmitted with details of the created order
     */
    function createOrderVault(ILiquidator.CreateVaultOrderParams calldata params) external onlyLiquidator {
        Details memory details = Details(params.sellToken, params.sellAmount, params.buyToken);

        address liquidator = _initializeVaultLiquidator(params.internalRefId, details, params.orderUid);

        // record the order details
        orderCalls[params.internalRefId] = Orders(details, liquidator, params.vaultId, address(MODULE_CORE));

        _moveVaultFunds(details, params.vaultId, liquidator);

        // Emit an event with order details for the backend to pick up
        emit OrderSubmitted(
            params.internalRefId,
            address(MODULE_CORE),
            params.orderUid,
            params.sellToken,
            params.sellAmount,
            params.buyToken,
            liquidator
        );
    }

    /**
     * @notice Creates a new order to liquidate assets from a Protected Unit
     * @dev Sets up a child liquidator and records order details for tracking
     * @param params The parameters for the liquidation:
     *        - sellToken: Which token to sell
     *        - sellAmount: How many tokens to sell
     *        - buyToken: Which token to buy
     *        - internalRefId: Unique identifier for tracking
     *        - orderUid: CoW Protocol order identifier
     *        - protectedUnit: Address of the Protected Unit
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If requesting or transferring funds fails
     * @custom:emits OrderSubmitted with details of the created order
     */
    function createOrderProtectedUnit(ILiquidator.CreateProtectedUnitOrderParams calldata params)
        external
        onlyLiquidator
    {
        Details memory details = Details(params.sellToken, params.sellAmount, params.buyToken);

        address liquidator =
            _initializeProtectedUnitLiquidator(params.internalRefId, details, params.orderUid, params.protectedUnit);

        // record the order details
        orderCalls[params.internalRefId] = Orders(details, liquidator, Id.wrap(bytes32("")), params.protectedUnit);

        _moveProtectedUnitFunds(details, params.protectedUnit, liquidator);

        // Emit an event with order details for the backend to pick up
        emit OrderSubmitted(
            params.internalRefId,
            params.protectedUnit,
            params.orderUid,
            params.sellToken,
            params.sellAmount,
            params.buyToken,
            liquidator
        );
    }

    /**
     * @notice Completes a vault liquidation order
     * @dev Moves acquired funds from the child liquidator to their final destination
     * @param refId The unique identifier of the order to complete
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If the child liquidator fails to move funds
     */
    function finishVaultOrder(bytes32 refId) external onlyLiquidator {
        Orders memory order = orderCalls[refId];

        VaultChildLiquidator(order.liquidator).moveFunds(order.vaultId);

        delete orderCalls[refId];
    }

    /**
     * @notice Completes a Protected Unit liquidation order
     * @dev Moves acquired funds from the child liquidator to their final destination
     * @param refId The unique identifier of the order to complete
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If the child liquidator fails to move funds
     */
    function finishProtectedUnitOrder(bytes32 refId) external onlyLiquidator {
        Orders memory order = orderCalls[refId];

        ProtectedUnitChildLiquidator(order.liquidator).moveFunds();

        delete orderCalls[refId];
    }

    /**
     * @notice Completes a Protected Unit liquidation and executes a trade
     * @param refId The unique identifier of the order
     * @param amountOutMin Minimum amount of tokens to receive from the trade
     * @param params Parameters for the trade execution
     * @param offchainGuess Suggested parameters from off-chain calculations for the trade
     * @return amountOut How many tokens were received from the trade
     * @custom:reverts OnlyLiquidator if caller is not an authorized liquidator
     * @custom:reverts If moving funds from the child liquidator fails
     */
    function finishProtectedUnitOrderAndExecuteTrade(
        bytes32 refId,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external onlyLiquidator returns (uint256 amountOut) {
        Orders memory order = orderCalls[refId];

        (uint256 funds,) = ProtectedUnitChildLiquidator(order.liquidator).moveFunds();

        // we don't want to revert if the trade fails
        try ProtectedUnit(order.receiver).useFunds(funds, amountOutMin, params, offchainGuess) returns (
            uint256 _amountOut
        ) {
            amountOut = _amountOut;
            // solhint-disable-next-line no-empty-blocks
        } catch {}

        delete orderCalls[refId];
    }
}
