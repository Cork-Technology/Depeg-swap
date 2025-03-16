// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ProtectedUnit} from "./ProtectedUnit.sol";
import {IProtectedUnitRouter} from "../../interfaces/IProtectedUnitRouter.sol";
import {MinimalSignatureHelper, Signature} from "./../../libraries/SignatureHelperLib.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Protected Unit Router
 * @notice A contract that helps users interact with multiple Protected Units at once
 * @dev Provides batch operations for minting and burning Protected Unit tokens.
 *      Serves as a convenience layer to reduce gas costs and improve UX when
 *      interacting with multiple Protected Unit contracts in a single transaction.
 * @author Cork Protocol Team
 */
contract ProtectedUnitRouter is IProtectedUnitRouter, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    // Permit2 contract address
    IPermit2 public immutable permit2;

    constructor(address _permit2) {
        permit2 = IPermit2(_permit2);
    }

    /**
     * @notice Calculates the tokens needed for minting multiple Protected Units in single function call
     * @dev Iterates through each Protected Unit to calculate the required token amounts.
     *      So Recommended to keep the number of Protected Units under 10 to avoid gas issues
     * @param protectedUnits List of Protected Unit contract addresses to mint from
     * @param amounts How many tokens to mint from those respective Protected Unit contract
     * @return dsAmounts List of DS token amounts needed for respective Protected Unit token minting
     * @return paAmounts List of PA token amounts needed for respective Protected Unit token minting
     * @custom:reverts InvalidInput if input array lengths don't match
     */
    function previewBatchMint(address[] calldata protectedUnits, uint256[] calldata amounts)
        external
        view
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts)
    {
        if (protectedUnits.length != amounts.length) {
            revert InvalidInput();
        }
        uint256 length = protectedUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);

        // If large number of ProtectedUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 ProtectedUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            (dsAmounts[i], paAmounts[i]) = ProtectedUnit(protectedUnits[i]).previewMint(amounts[i]);
        }
    }

    /**
     * @notice Creates multiple Protected Unit tokens in one transaction
     * @dev Iterates through each Protected Unit to mint tokens using permit signatures.
     *      Recommended to keep the number of Protected Units under 10 to avoid gas issues
     * @param params All parameters needed for batch minting:
     *        - protectedUnits: List of Protected Unit contract addresses to mint from
     *        - amounts: How many tokens to mint from respective Protected Unit contract
     *        - permitBatchData: The Permit2 batch permit data covering all tokens
     *        - transferDetails: Details for each token transfer
     *        - signature: The signature authorizing the permits
     * @return dsAmounts List of DS token amounts used for respective Protected Unit token minting
     * @return paAmounts List of PA token amounts used for respective Protected Unit token minting
     * @custom:reverts InvalidInput if input array lengths don't match
     * @custom:reverts If any of the individual mint operations fail
     */
    function batchMint(BatchMintParams calldata params)
        external
        nonReentrant
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts)
    {
        if (
            params.protectedUnits.length != params.amounts.length
                || params.permitBatchData.permitted.length != params.transferDetails.length
        ) {
            revert InvalidInput();
        }

        uint256 length = params.protectedUnits.length;
        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);

        // Execute the permitTransferFrom to approve all tokens in one transaction
        permit2.permitTransferFrom(params.permitBatchData, params.transferDetails, msg.sender, params.signature);

        // Now mint from each ProtectedUnit
        for (uint256 i = 0; i < length; ++i) {
            ProtectedUnit protectedUnit = ProtectedUnit(params.protectedUnits[i]);

            // Calculate indices for this ProtectedUnit's DS and PA tokens
            uint256 dsIndex = i * 2;
            uint256 paIndex = dsIndex + 1;

            // Approve the tokens for the ProtectedUnit
            IERC20(params.permitBatchData.permitted[dsIndex].token).safeIncreaseAllowance(
                address(protectedUnit), params.transferDetails[dsIndex].requestedAmount
            );
            IERC20(params.permitBatchData.permitted[paIndex].token).safeIncreaseAllowance(
                address(protectedUnit), params.transferDetails[paIndex].requestedAmount
            );

            // Mint the tokens
            (dsAmounts[i], paAmounts[i]) = protectedUnit.mint(params.amounts[i]);

            // Send back the remaining tokens to the user
            if (dsAmounts[i] < params.transferDetails[dsIndex].requestedAmount) {
                IERC20(params.permitBatchData.permitted[dsIndex].token).safeTransfer(
                    msg.sender, params.transferDetails[dsIndex].requestedAmount - dsAmounts[i]
                );
            }
            if (paAmounts[i] < params.transferDetails[paIndex].requestedAmount) {
                IERC20(params.permitBatchData.permitted[paIndex].token).safeTransfer(
                    msg.sender, params.transferDetails[paIndex].requestedAmount - paAmounts[i]
                );
            }
        }
    }

    /**
     * @notice Calculates the tokens user will receive for burning multiple Protected Units
     * @dev Iterates through each Protected Unit to calculate the returned token amounts.
     *      Recommended to keep the number of Protected Units under 10 to avoid gas issues
     * @param protectedUnits List of Protected Unit contract addresses to burn tokens from
     * @param amounts How many tokens to burn from respective Protected Unit contract
     * @return dsAmounts List of DS token amounts user will receive from respective Protected Unit token burning
     * @return paAmounts List of PA token amounts user will receive from respective Protected Unit token burning
     * @return raAmounts List of RA token amounts user will receive from respective Protected Unit token burning
     * @custom:reverts InvalidInput if input array lengths don't match
     * @custom:reverts If any of the individual burn operations fail
     */
    function previewBatchBurn(address[] calldata protectedUnits, uint256[] calldata amounts)
        external
        view
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts, uint256[] memory raAmounts)
    {
        if (protectedUnits.length != amounts.length) {
            revert InvalidInput();
        }
        uint256 length = protectedUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);
        raAmounts = new uint256[](length);

        // If large number of ProtectedUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 ProtectedUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            (dsAmounts[i], paAmounts[i], raAmounts[i]) =
                ProtectedUnit(protectedUnits[i]).previewBurn(msg.sender, amounts[i]);
        }
    }

    /**
     * @notice Burns multiple Protected Unit tokens in one transaction
     * @dev Iterates through respective Protected Unit to burn tokens.
     *      Recommended to keep the number of Protected Units under 10 to avoid gas issues
     * @param protectedUnits List of Protected Unit contract addresses to burn from
     * @param amounts How many tokens to burn from respective Protected Unit contract
     * @return dsAdds List of DS token addresses for DS token received from respective Protected Unit token burning
     * @return paAdds List of PA token addresses for PA token received from respective Protected Unit token burning
     * @return raAdds List of RA token addresses for RA token received from respective Protected Unit token burning
     * @return dsAmounts List of DS token amounts received from respective Protected Unit token burning
     * @return paAmounts List of PA token amounts received from respective Protected Unit token burning
     * @return raAmounts List of RA token amounts received from respective Protected Unit token burning
     * @custom:reverts InvalidInput if input array lengths don't match
     * @custom:reverts If any of the individual burn operations fail
     */
    function batchBurn(address[] calldata protectedUnits, uint256[] calldata amounts)
        external
        nonReentrant
        returns (
            address[] memory dsAdds,
            address[] memory paAdds,
            address[] memory raAdds,
            uint256[] memory dsAmounts,
            uint256[] memory paAmounts,
            uint256[] memory raAmounts
        )
    {
        (paAdds, dsAdds, raAdds, dsAmounts, paAmounts, raAmounts) = _batchBurn(protectedUnits, amounts);
    }

    /**
     * @notice Burns multiple Protected Unit tokens using signed permissions
     * @param protectedUnits List of Protected Unit contracts to burn from
     * @param amounts How many tokens to burn from respective Protected Unit contract
     * @param permits List of permission parameters for respective Protected Unit token burning
     * @return dsAdds List of DS token addresses for DS token received from respective Protected Unit token burning
     * @return paAdds List of PA token addresses for PA token received from respective Protected Unit token burning
     * @return raAdds List of RA token addresses for RA token received from respective Protected Unit token burning
     * @return dsAmounts List of DS token amounts received from each burn
     * @return paAmounts List of PA token amounts received from each burn
     * @return raAmounts List of RA token amounts received from each burn
     * @custom:reverts InvalidInput if input array lengths don't match
     * @custom:reverts If any permit signature is invalid
     * @custom:reverts If any of the individual burn operations fail
     */
    function batchBurn(
        address[] calldata protectedUnits,
        uint256[] calldata amounts,
        BatchBurnPermitParams[] calldata permits
    )
        external
        nonReentrant
        returns (
            address[] memory dsAdds,
            address[] memory paAdds,
            address[] memory raAdds,
            uint256[] memory dsAmounts,
            uint256[] memory paAmounts,
            uint256[] memory raAmounts
        )
    {
        uint256 length = permits.length;
        for (uint256 i = 0; i < length; ++i) {
            ProtectedUnit protectedUnit = ProtectedUnit(protectedUnits[i]);
            BatchBurnPermitParams calldata permit = permits[i];

            Signature memory signature = MinimalSignatureHelper.split(permit.rawProtectedUnitPermitSig);

            protectedUnit.permit(
                permit.owner, permit.spender, permit.value, permit.deadline, signature.v, signature.r, signature.s
            );
        }

        (paAdds, dsAdds, raAdds, dsAmounts, paAmounts, raAmounts) = _batchBurn(protectedUnits, amounts);
    }

    /// @notice Internal function to handle the batch burning logic
    function _batchBurn(address[] calldata protectedUnits, uint256[] calldata amounts)
        internal
        returns (
            address[] memory dsAdds,
            address[] memory paAdds,
            address[] memory raAdds,
            uint256[] memory dsAmounts,
            uint256[] memory paAmounts,
            uint256[] memory raAmounts
        )
    {
        if (protectedUnits.length != amounts.length) {
            revert InvalidInput();
        }
        uint256 length = protectedUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);
        raAmounts = new uint256[](length);
        dsAdds = new address[](length);
        paAdds = new address[](length);
        raAdds = new address[](length);

        // If large number of ProtectedUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 ProtectedUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            ProtectedUnit protectedUnit = ProtectedUnit(protectedUnits[i]);

            dsAdds[i] = protectedUnit.latestDs();
            paAdds[i] = address(protectedUnit.PA());
            raAdds[i] = address(protectedUnit.RA());

            (dsAmounts[i], paAmounts[i], raAmounts[i]) = protectedUnit.previewBurn(msg.sender, amounts[i]);

            ProtectedUnit(protectedUnits[i]).burnFrom(msg.sender, amounts[i]);
        }
    }
}
