// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ProtectedUnit} from "./ProtectedUnit.sol";
import {IProtectedUnitRouter} from "../../interfaces/IProtectedUnitRouter.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

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
    IPermit2 public immutable PERMIT2;

    constructor(address _permit2) {
        PERMIT2 = IPermit2(_permit2);
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
     *        - permitBatchData: The Permit2 batch permit data covering all tokens - Assumes that Array contains DS and PA one after the other as per protectedUnits array
     *        - transferDetails: Details for each token transfer - Assumes that Array contains DS and PA one after the other as per protectedUnits array
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
        uint256 length = params.protectedUnits.length;
        if (
            length != params.amounts.length || length * 2 != params.permitBatchData.permitted.length
                || params.permitBatchData.permitted.length != params.transferDetails.length
        ) {
            revert InvalidInput();
        }

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);

        // Execute the permitTransferFrom to approve all tokens in one transaction
        PERMIT2.permitTransferFrom(params.permitBatchData, params.transferDetails, msg.sender, params.signature);

        // Now mint from each ProtectedUnit
        for (uint256 i = 0; i < length; ++i) {
            ProtectedUnit protectedUnit = ProtectedUnit(params.protectedUnits[i]);

            // Calculate indices for this ProtectedUnit's DS and PA tokens
            // Assumes that Array contains DS and PA one after the other and in same order as per protectedUnits array
            // paIndex = dsIndex + 1
            uint256 dsIndex = i * 2;

            // Get token addresses
            address dsToken = params.permitBatchData.permitted[dsIndex].token;
            address paToken = params.permitBatchData.permitted[dsIndex + 1].token;

            // Approve the tokens to Permit2
            IERC20(dsToken).approve(address(PERMIT2), params.transferDetails[dsIndex].requestedAmount);
            IERC20(paToken).approve(address(PERMIT2), params.transferDetails[dsIndex + 1].requestedAmount);

            // Approve the tokens to the ProtectedUnit in Permit2
            PERMIT2.approve(
                dsToken, address(protectedUnit), SafeCast.toUint160(params.transferDetails[dsIndex].requestedAmount), 0
            );
            PERMIT2.approve(
                paToken,
                address(protectedUnit),
                SafeCast.toUint160(params.transferDetails[dsIndex + 1].requestedAmount),
                0
            );

            // Mint the tokens
            (dsAmounts[i], paAmounts[i]) = protectedUnit.mint(params.amounts[i]);

            // Send back users ProtectedUnit tokens
            IERC20(address(protectedUnit)).safeTransfer(msg.sender, params.amounts[i]);
        }

        // Return any unused permitted tokens back to the user
        _returnExcessTokens(params.permitBatchData);
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
        (paAdds, dsAdds, raAdds, dsAmounts, paAmounts, raAmounts) = _batchBurn(protectedUnits, amounts, msg.sender);
    }

    /**
     * @notice Burns multiple Protected Unit tokens using signed permissions
     * @dev Recommended to keep the number of Protected Units under 10 to avoid gas issues
     * @param params All parameters needed for batch burning with permit2:
     *        - protectedUnits: List of Protected Unit contract addresses to burn from
     *        - amounts: How many tokens to burn from respective Protected Unit contract
     *        - permitBatchData: The Permit2 batch permit data covering all tokens
     *        - transferDetails: Details for each token transfer
     *        - signature: The signature authorizing the permits
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
    function batchBurn(BatchBurnPermitParams calldata params)
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
        uint256 length = params.protectedUnits.length;
        if (
            length != params.amounts.length || length != params.transferDetails.length
                || length != params.permitBatchData.permitted.length
        ) {
            revert InvalidInput();
        }

        // Execute the permitTransferFrom to transfer all Protected Unit tokens to this contract
        PERMIT2.permitTransferFrom(params.permitBatchData, params.transferDetails, msg.sender, params.signature);

        // Process the batch burn
        (dsAdds, paAdds, raAdds, dsAmounts, paAmounts, raAmounts) =
            _batchBurn(params.protectedUnits, params.amounts, address(this));

        // Return any excess tokens that were permitted but not needed for the burn
        _returnExcessTokens(params.permitBatchData);
    }

    /// @notice Internal function to handle the batch burning logic
    function _batchBurn(address[] calldata protectedUnits, uint256[] calldata amounts, address caller)
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
        uint256 length = protectedUnits.length;
        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);
        raAmounts = new uint256[](length);
        dsAdds = new address[](length);
        paAdds = new address[](length);
        raAdds = new address[](length);

        // Now process each burn operation
        // If large number of ProtectedUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 ProtectedUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            ProtectedUnit protectedUnit = ProtectedUnit(protectedUnits[i]);

            dsAdds[i] = protectedUnit.latestDs();
            paAdds[i] = address(protectedUnit.pa());
            raAdds[i] = address(protectedUnit.ra());

            // Calculate tokens to be received
            (dsAmounts[i], paAmounts[i], raAmounts[i]) = protectedUnit.previewBurn(caller, amounts[i]);

            // Burn tokens
            protectedUnit.burnFrom(caller, amounts[i]);

            if (caller == address(this)) {
                // Transfer the underlying tokens to the user
                IERC20(dsAdds[i]).safeTransfer(msg.sender, dsAmounts[i]);
                IERC20(paAdds[i]).safeTransfer(msg.sender, paAmounts[i]);
                IERC20(raAdds[i]).safeTransfer(msg.sender, raAmounts[i]);
            }
        }
    }

    /**
     * @notice Helper function to track token usage
     * @dev Adds or updates a token's usage amount in the tracking arrays
     * @param usedTokens Array of token addresses being tracked
     * @param usedAmounts Array of amounts used for each token
     * @param token Address of the token to track
     * @param amount Amount of the token used
     */
    function _trackTokenUsage(address[] memory usedTokens, uint256[] memory usedAmounts, address token, uint256 amount)
        internal
        pure
    {
        // Look for the token in the existing array
        uint256 length = usedTokens.length;
        for (uint256 i = 0; i < length; ++i) {
            if (usedTokens[i] == token) {
                // Token already being tracked, add to the amount
                usedAmounts[i] += amount;
                return;
            } else if (usedTokens[i] == address(0)) {
                // Found an empty slot, use it to track this token
                usedTokens[i] = token;
                usedAmounts[i] = amount;
                return;
            }
        }
        // If we get here, the arrays are full which shouldn't happen
        // as we initialize them with the correct size
    }

    /**
     * @notice Helper function to return excess tokens to the user
     * @dev Compares requested amounts with actual usage and returns any excess
     * @param permitBatchData The Permit2 batch permit data
     */
    function _returnExcessTokens(IPermit2.PermitBatchTransferFrom calldata permitBatchData) internal {
        uint256 length = permitBatchData.permitted.length;

        for (uint256 i = 0; i < length; ++i) {
            // since the router isn't supposed to hold funds, we just transfer what's left
            IERC20 token = IERC20(permitBatchData.permitted[i].token);
            token.safeTransfer(msg.sender, token.balanceOf(address(this)));
        }
    }
}
