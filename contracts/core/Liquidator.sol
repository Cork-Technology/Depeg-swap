pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidator} from "../interfaces/ILiquidator.sol";
import {CowswapHelper} from "../libraries/cowswap/CowswapHelper.sol";

interface ISettlement {
    function setPreSignature(bytes calldata orderUid, bool signed) external;
}

contract Liquidator is Ownable, ReentrancyGuard, ILiquidator {
    using SafeERC20 for IERC20;

    CowswapHelper public cowswapHelper;

    // Default expiry interval for orders, can be updated
    uint256 public expiryInterval;
    // Address of the CowSwap settlement contract
    address public settlementContract;
    // Counter for generating unique order UIDs
    uint256 private orderCounter;

    constructor(address _owner, uint256 _expiryInterval, address _settlementContract) Ownable(_owner) {
        expiryInterval = _expiryInterval;
        settlementContract = _settlementContract;

        cowswapHelper = new CowswapHelper(_settlementContract);
    }

    // Update the expiry interval for all swaps
    function updateExpiryInterval(uint256 newExpiryInterval) external onlyOwner {
        expiryInterval = newExpiryInterval;
    }

    // Update the CowSwap settlement contract address
    function updateSettlementContract(address newSettlementContract) external onlyOwner {
        settlementContract = newSettlementContract;
    }

    // Liquidate RA for PA for any RA-PA pair specified in function call
    function liquidateRaForPa(address raToken, address paToken, uint256 raAmount, uint256 paAmount)
        external
        onlyOwner
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
