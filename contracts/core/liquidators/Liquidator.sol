pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidator} from "../../interfaces/ILiquidator.sol";
import {OrderHelper} from "./OrderHelper.sol";

interface ISettlement {
    function setPreSignature(bytes calldata orderUid, bool signed) external;
}

contract Liquidator is AccessControl, ReentrancyGuardTransient, ILiquidator {
    using SafeERC20 for IERC20;

    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    // Default expiry interval for orders, can be updated
    uint256 public expiryInterval;
    // Address of the CowSwap settlement contract
    address public settlementContract;

    constructor(address _admin, uint256 _expiryInterval, address _settlementContract) {
        expiryInterval = _expiryInterval;
        settlementContract = _settlementContract;


    }

    // Liquidate RA for PA for any RA-PA pair specified in function call
    function liquidateRaForPa(address raToken, address paToken, uint256 raAmount, uint256 paAmount)
        external
        onlyRole(LIQUIDATOR_ROLE)
        nonReentrant
        returns (bool)
    {
        uint256 expiry = block.timestamp + expiryInterval;

        // Transfer RA tokens from caller to this contract
        IERC20(raToken).safeTransferFrom(msg.sender, address(this), raAmount);
        // Approve the CowSwap settlement contract to spend `amount` of `raToken`
        IERC20(raToken).safeIncreaseAllowance(settlementContract, raAmount);

        CowswapHelper.Data memory order = CowswapHelper.Data({
            sellToken: IERC20(raToken),
            buyToken: IERC20(paToken),
            receiver: address(this),
            sellAmount: raAmount,
            buyAmount: paAmount,
            validTo: uint32(expiry),
            appData: 0xb48d38f93eaa084033fc5970bf96e559c33c4cdc07d889ab00b4d63f9590739d,
            feeAmount: 0,
            kind: keccak256("sell"),
            partiallyFillable: true,
            sellTokenBalance: keccak256("erc20"),
            buyTokenBalance: keccak256("erc20")
        });

        bytes32 orderDigest = cowswapHelper.hash(order);
        bytes memory orderUid = cowswapHelper.packOrderUidParams(orderDigest, address(this), uint32(expiry));

        // Call the settlement contract to set pre-signature
        ISettlement(settlementContract).setPreSignature(orderUid, true);

        // Emit an event with order details for the backend to pick up
        emit OrderRequest(raToken, paToken, raAmount, paAmount, expiry, msg.sender, orderUid);

        return true;
    }

    function preHook() external override {}

    function postHook() external override {}
}
