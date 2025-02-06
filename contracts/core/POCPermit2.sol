// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPermit2} from "../interfaces/uniswap-v2/Permit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureTransfer} from "../interfaces/uniswap-v2/SignatureTransfer.sol";

contract TokenTransfer {
    IPermit2 public permit2;
    address public usdc;

    constructor(address _permit2, address _usdc) {
        permit2 = IPermit2(_permit2);
        usdc = _usdc;
    }

    function transferWithSignature(
        address owner,
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        // Approve Permit2 to spend the owner's USDC
        IERC20(usdc).approve(address(permit2), type(uint256).max);

        ISignatureTransfer.TokenPermissions memory permitted = ISignatureTransfer.TokenPermissions({
                token: usdc,
                amount: amount
        });

        // Create the permit struct
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: permitted,
            nonce: nonce,
            deadline: deadline
        });

        // Create the transfer details struct
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: to,
            requestedAmount: amount
        });

        // Call permitTransferFrom on the Permit2 contract
        permit2.permitTransferFrom(permit, transferDetails, owner, signature);
    }
}