// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidator} from "../../../interfaces/ILiquidator.sol";
import {BalancesSnapshot} from "./../../../libraries/BalanceSnapshotLib.sol";
import {IVaultLiquidation} from "./../../../interfaces/IVaultLiquidation.sol";
import {Id} from "./../../../libraries/Pair.sol";
import {CorkConfig} from "./../../CorkConfig.sol";
// import {VaultChildLiquidator} from "./VaultChildLiquidator.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

interface GPv2SettlementContract {
    function setPreSignature(bytes calldata orderUid, bool signed) external;
}

contract Liquidator is ReentrancyGuardTransient, ILiquidator {
    using SafeERC20 for IERC20;

    struct Details {
        address sellToken;
        uint256 sellAmount;
        address buyToken;
        Call preHookCall;
        Call postHookCall;
    }

    GPv2SettlementContract public settlement;

    mapping(bytes32 => Details) internal orderCalls;
    mapping(address => bool) public liquidators;

    address public config;
    address public hookTrampoline;
    address public vaultLiquidatorBase;

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

    constructor(address _config, address _hookTrampoline, address _settlementContract) {
        settlement = GPv2SettlementContract(_settlementContract);
        config = _config;
        hookTrampoline = _hookTrampoline;
    }

    // function registerRefId(bytes32 refId) external onlyLiquidator {
    //     Clones.cloneDeterministic(implementation, salt);
    //     Clones.predictDeterministicAddress(implementation, salt);
    // }

    function createOrder(ILiquidator.CreateOrderParams memory params, uint32 expiryPeriodInSecods)
        external
        nonReentrant
        onlyLiquidator
    {
        // record the order details
        orderCalls[params.internalRefId] =
            Details(params.sellToken, params.sellAmount, params.buyToken, params.preHookCall, params.postHookCall);

        // Call the settlement contract to set pre-signature
        settlement.setPreSignature(params.orderUid, true);

        // Emit an event with order details for the backend to pick up
        emit OrderSubmitted(params.internalRefId, params.orderUid, params.sellToken, params.sellAmount, params.buyToken);
    }

    function preHook(bytes32 refId) external nonReentrant onlyTrampoline {
        Details memory details = orderCalls[refId];

        if (details.preHookCall.target == address(0)) {
            revert ILiquidator.InalidRefId();
        }

        // call the funds owner, the funds is expected to be in the liquidator contract after this call
        details.preHookCall.target.call(details.preHookCall.data);

        // make a snapshot of the liquidation contract balance
        BalancesSnapshot.takeSnapshot(details.buyToken);

        // give the settlement contract allowance to spend the funds
        SafeERC20.safeIncreaseAllowance(IERC20(details.sellToken), address(settlement), details.sellAmount);
    }

    function postHook(bytes32 refId) external nonReentrant onlyTrampoline {
        Details memory details = orderCalls[refId];

        if (details.preHookCall.target == address(0)) {
            revert ILiquidator.InalidRefId();
        }

        uint256 balanceDiff = BalancesSnapshot.getDifferences(details.buyToken);

        // actually encode the balance difference in the postHookCall data
        details.postHookCall.data = bytes.concat(details.postHookCall.data, abi.encode(balanceDiff));

        // increase allowance
        SafeERC20.safeIncreaseAllowance(IERC20(details.buyToken), details.postHookCall.target, balanceDiff);

        // call the funds owner, we expect the funds to be taken away from the liquidator contract after this call
        details.postHookCall.target.call(details.postHookCall.data);

        // remove the order details to save gas
        delete orderCalls[refId];
    }

    function encodePreHookCallData(bytes32 refId) external returns (bytes memory data) {
        data = abi.encodeCall(this.preHook, refId);
    }

    function encodePostHookCallData(bytes32 refId) external returns (bytes memory data) {
        data = abi.encodeCall(this.postHook, refId);
    }

    // needed since the resulting trade amount isn't fixed and can get more than the expected amount
    // IMPORTANT:  this will encode all the data needed EXCEPT the amount of the trade, it's important that the amount
    // is placed LAST in terms of the function signature variable ordering
    function encodeVaultPostHook(Id vaultId) external returns (bytes memory data) {
        data = abi.encodeWithSelector(IVaultLiquidation.receiveTradeExecuctionResultFunds.selector, vaultId);
    }

    function encodeVaultPreHook(Id vaultId, uint256 amount) external returns (bytes memory data) {
        data = abi.encodeWithSelector(IVaultLiquidation.requestLiquidationFunds.selector, vaultId, amount);
    }

    // needed since the resulting trade amount isn't fixed and can get more than the expected amount
    // IMPORTANT:  this will encode all the data needed EXCEPT the amount of the trade, it's important that the amount
    // is placed LAST in terms of the function signature variable ordering
    function encodeHedgeUnitPostHook() external {
        // TODO
    }
}
