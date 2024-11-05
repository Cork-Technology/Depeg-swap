pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidator} from "../interfaces/ILiquidator.sol";

interface ISettlement {
    function setPreSignature(bytes calldata orderUid, bool signed) external;
}

contract Liquidator is Ownable, ReentrancyGuard, ILiquidator {
    using SafeERC20 for IERC20;

    // Default expiry interval for orders, can be updated
    uint256 public expiryInterval;
    // Address of the CowSwap settlement contract
    address public settlementContract;
    // Counter for generating unique order UIDs
    uint256 private orderCounter;

    constructor(address _owner, uint256 _expiryInterval, address _settlementContract) Ownable(_owner) {
        expiryInterval = _expiryInterval;
        settlementContract = _settlementContract;
    }

    // Update the expiry interval for all swaps
    function setExpiryInterval(uint256 newExpiryInterval) external onlyOwner {
        expiryInterval = newExpiryInterval;
    }

    // Update the CowSwap settlement contract address
    function setSettlementContract(address newSettlementContract) external onlyOwner {
        settlementContract = newSettlementContract;
    }

    // Liquidate RA for PA for any RA-PA pair specified in function call
    function liquidateRaForPa(address raToken, address paToken, uint256 amount, uint256 minAmount)
        external
        onlyOwner
        nonReentrant
        returns (bool)
    {
        uint256 expiry = block.timestamp + expiryInterval;

        // Transfer RA tokens from caller to this contract
        IERC20(raToken).safeTransferFrom(msg.sender, address(this), amount);
        // Approve the CowSwap settlement contract to spend `amount` of `raToken`
        IERC20(raToken).safeIncreaseAllowance(settlementContract, amount);

        // Generate the order UID as a bytes32 hash
        bytes32 orderUid = keccak256(abi.encodePacked(orderCounter, raToken, paToken, amount, expiry));
        orderCounter++; // Increment for the next order

        // Call the settlement contract to set pre-signature
        ISettlement(settlementContract).setPreSignature(abi.encode(orderUid), true);

        // Emit an event with order details for the backend to pick up
        emit OrderRequest(raToken, paToken, amount, minAmount, expiry, msg.sender, orderUid);

        return true;
    }

    // This function will be called by CowSwap once the swap is executed
    function onSwapExecuted(
        uint256 orderId,
        address raToken,
        address paToken,
        uint256 amount,
        uint256 receivedAmount,
        string memory status
    ) external {
        // Emit an event indicating the swap has been executed
        emit SwapExecuted(orderId, raToken, paToken, amount, receivedAmount, status);
    }
}
