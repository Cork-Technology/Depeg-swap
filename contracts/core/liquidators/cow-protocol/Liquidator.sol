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

interface IGPv2SettlementContract {
    function setPreSignature(bytes calldata orderUid, bool signed) external;
}

contract Liquidator is ILiquidator {
    using SafeERC20 for IERC20;

    struct Details {
        address sellToken;
        uint256 sellAmount;
        address buyToken;
    }

    struct Orders {
        Details details;
        address liquidator;
        // if not present then it's protected unit
        Id vaultId;
        address receiver;
    }

    IGPv2SettlementContract public immutable SETTLEMENT;

    address public immutable CONFIG;
    address public immutable HOOK_TRAMPOLINE;
    address public immutable VAULT_LIQUIDATOR_BASE;
    address public immutable PROTECTED_UNIT_LIQUIDATOR_BASE;
    address public immutable MODULE_CORE;

    mapping(bytes32 => Orders) internal orderCalls;

    modifier onlyTrampoline() {
        if (msg.sender != HOOK_TRAMPOLINE) {
            revert IErrors.OnlyTrampoline();
        }
        _;
    }

    modifier onlyLiquidator() {
        if (!CorkConfig(CONFIG).isTrustedLiquidationExecutor(address(this), msg.sender)) {
            revert IErrors.OnlyLiquidator();
        }
        _;
    }

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

    function fetchVaultReceiver(bytes32 refId) external returns (address receiver) {
        receiver = Clones.predictDeterministicAddress(VAULT_LIQUIDATOR_BASE, refId, address(this));
    }

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
        IProtectedUnitLiquidation(protectedUnit).requestLiquidationFunds(details.sellAmount, details.sellToken);

        SafeERC20.safeTransfer(IERC20(details.sellToken), liquidator, details.sellAmount);
    }

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

    function finishVaultOrder(bytes32 refId) external onlyLiquidator {
        Orders memory order = orderCalls[refId];

        VaultChildLiquidator(order.liquidator).moveFunds(order.vaultId);

        delete orderCalls[refId];
    }

    function finishProtectedUnitOrder(bytes32 refId) external onlyLiquidator {
        Orders memory order = orderCalls[refId];

        ProtectedUnitChildLiquidator(order.liquidator).moveFunds();

        delete orderCalls[refId];
    }

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
