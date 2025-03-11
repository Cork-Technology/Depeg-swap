// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ProtectedUnit} from "./ProtectedUnit.sol";
import {IProtectedUnitRouter} from "../../interfaces/IProtectedUnitRouter.sol";
import {MinimalSignatureHelper, Signature} from "./../../libraries/SignatureHelperLib.sol";

/**
 * @title Protected Unit Router
 * @notice A contract that helps users interact with multiple Protected Units at once
 * @dev Provides batch operations for minting and burning Protected Unit tokens.
 *      Serves as a convenience layer to reduce gas costs and improve UX when
 *      interacting with multiple Protected Unit contracts in a single transaction.
 * @author Cork Protocol Team
 */
contract ProtectedUnitRouter is IProtectedUnitRouter, ReentrancyGuardTransient {
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
     *        - deadline: Time until which the transaction is valid
     *        - protectedUnits: List of Protected Unit contract addresses to mint from
     *        - amounts: How many tokens to mint from respective Protected Unit contract
     *        - rawDsPermitSigs: Permission signatures for DS tokens
     *        - rawPaPermitSigs: Permission signatures for PA tokens
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
        if (params.protectedUnits.length != params.amounts.length) {
            revert InvalidInput();
        }
        uint256 length = params.protectedUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);

        // If large number of ProtectedUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 ProtectedUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            (dsAmounts[i], paAmounts[i]) = ProtectedUnit(params.protectedUnits[i]).mint(
                msg.sender, params.amounts[i], params.rawDsPermitSigs[i], params.rawPaPermitSigs[i], params.deadline
            );
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
     * @notice Burns multiple protected units in a batch process.
     * @dev This function allows the caller to burn multiple protected units by providing the necessary permits.
     * @param protectedUnits An array of addresses of the protected units to be burned.
     * @param amounts An array of amounts corresponding to each protected unit to be burned.
     * @param permits An array of permit parameters required for the batch burn operation.
     * @return dsAdds An array of addresses for the destination addresses.
     * @return paAdds An array of addresses for the protected asset addresses.
     * @return raAdds An array of addresses for the reserve asset addresses.
     * @return dsAmounts An array of amounts for the destination amounts.
     * @return paAmounts An array of amounts for the protected asset amounts.
     * @return raAmounts An array of amounts for the reserve asset amounts.
     */
    function batchBurn(
        address[] calldata protectedUnits,
        uint256[] calldata amounts,
        IProtectedUnitRouter.BatchBurnPermitParams[] calldata permits
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
            IProtectedUnitRouter.BatchBurnPermitParams calldata permit = permits[i];

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
