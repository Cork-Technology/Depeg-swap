// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidator} from "../../../interfaces/ILiquidator.sol";
import {BalancesSnapshot} from "./../../../libraries/BalanceSnapshotLib.sol";
import {IVaultLiquidation} from "./../../../interfaces/IVaultLiquidation.sol";
import {Id} from "./../../../libraries/Pair.sol";
import {CorkConfig} from "./../../CorkConfig.sol";
import "./ChildLiquidator.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import "./../../../interfaces/IHedgeUnitLiquidation.sol";

interface GPv2SettlementContract {
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
        // if not present then it's hedge unit
        Id vaultId;
        address receiver;
    }

    GPv2SettlementContract public settlement;

    mapping(bytes32 => Orders) internal orderCalls;

    address public config;
    address public hookTrampoline;
    address public vaultLiquidatorBase;
    address public hedgeUnitLiquidatorBase;
    address public moduleCore;

    modifier onlyTrampoline() {
        if (msg.sender != hookTrampoline) {
            revert ILiquidator.OnlyTrampoline();
        }
        _;
    }

    modifier onlyLiquidator() {
        if (!CorkConfig(config).isTrustedLiquidationExecutor(address(this), msg.sender)) {
            revert ILiquidator.OnlyLiquidator();
        }
        _;
    }

    constructor(address _config, address _hookTrampoline, address _settlementContract, address _moduleCore) {
        settlement = GPv2SettlementContract(_settlementContract);
        config = _config;
        hookTrampoline = _hookTrampoline;
        vaultLiquidatorBase = address(new VaultChildLiquidator());
        hedgeUnitLiquidatorBase = address(new HedgeUnitChildLiquidator());
        moduleCore = _moduleCore;
    }

    function fetchVaultReceiver(bytes32 refId) external returns (address receiver) {
        receiver = Clones.predictDeterministicAddress(vaultLiquidatorBase, refId, address(this));
    }

    function fetchHedgeUnitReceiver(bytes32 refId) external returns (address receiver) {
        receiver = Clones.predictDeterministicAddress(hedgeUnitLiquidatorBase, refId, address(this));
    }

    function _initializeVaultLiquidator(bytes32 refId, Details memory order, bytes memory orderUid)
        internal
        returns (address liquidator)
    {
        liquidator = Clones.cloneDeterministic(vaultLiquidatorBase, refId);
        VaultChildLiquidator(liquidator).initialize(this, order, orderUid, moduleCore, refId);
    }

    function _initializeHedgeUnitLiquidator(
        bytes32 refId,
        Details memory order,
        bytes memory orderUid,
        address hedgeUnit
    ) internal returns (address liquidator) {
        liquidator = Clones.cloneDeterministic(hedgeUnitLiquidatorBase, refId);
        HedgeUnitChildLiquidator(liquidator).initialize(this, order, orderUid, hedgeUnit, refId);
    }

    function _moveVaultFunds(Details memory details, Id id, address liquidator) internal {
        IVaultLiquidation(moduleCore).requestLiquidationFunds(id, details.sellAmount);

        SafeERC20.safeTransfer(IERC20(details.sellToken), liquidator, details.sellAmount);
    }

    function _moveHedgeUnitFunds(Details memory details, address hedgeUnit, address liquidator) internal {
        IHedgeUnitLiquidation(hedgeUnit).requestLiquidationFunds(details.sellAmount, details.sellToken);

        SafeERC20.safeTransfer(IERC20(details.sellToken), liquidator, details.sellAmount);
    }

    function createOrderVault(ILiquidator.CreateVaultOrderParams memory params) external onlyLiquidator {
        Details memory details = Details(params.sellToken, params.sellAmount, params.buyToken);

        address liquidator = _initializeVaultLiquidator(params.internalRefId, details, params.orderUid);

        // record the order details
        orderCalls[params.internalRefId] = Orders(details, liquidator, params.vaultId, address(moduleCore));

        _moveVaultFunds(details, params.vaultId, liquidator);

        // Emit an event with order details for the backend to pick up
        emit OrderSubmitted(
            params.internalRefId,
            address(moduleCore),
            params.orderUid,
            params.sellToken,
            params.sellAmount,
            params.buyToken,
            liquidator
        );
    }

    function createOrderHedgeUnit(ILiquidator.CreateHedgeUnitOrderParams memory params) external onlyLiquidator {
        Details memory details = Details(params.sellToken, params.sellAmount, params.buyToken);

        address liquidator =
            _initializeHedgeUnitLiquidator(params.internalRefId, details, params.orderUid, params.hedgeUnit);

        // record the order details
        orderCalls[params.internalRefId] = Orders(details, liquidator, Id.wrap(bytes32("")), params.hedgeUnit);

        _moveHedgeUnitFunds(details, params.hedgeUnit, liquidator);

        // Emit an event with order details for the backend to pick up
        emit OrderSubmitted(
            params.internalRefId,
            params.hedgeUnit,
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

    function finishHedgeUnitOrder(bytes32 refId) external onlyLiquidator {
        Orders memory order = orderCalls[refId];

        HedgeUnitChildLiquidator(order.liquidator).moveFunds();

        delete orderCalls[refId];
    }

    function finishHedgeUnitOrderAndExecuteTrade(
        bytes32 refId,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params
    ) external onlyLiquidator {
        Orders memory order = orderCalls[refId];

        HedgeUnitChildLiquidator(order.liquidator).moveFundsAndExecuteTrade(amountOutMin, params);

        delete orderCalls[refId];
    }
}
