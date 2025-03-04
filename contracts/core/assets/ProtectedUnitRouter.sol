// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ProtectedUnit} from "./ProtectedUnit.sol";
import {IProtectedUnitRouter} from "../../interfaces/IProtectedUnitRouter.sol";
import {MinimalSignatureHelper, Signature} from "./../../libraries/SignatureHelperLib.sol";

/**
 * @title Protected Unit Router
 * @notice A contract that helps users interact with multiple Protected Units at once
 * @dev Provides batch operations for minting and burning Protected Unit tokens
 */
contract ProtectedUnitRouter is IProtectedUnitRouter, ReentrancyGuardTransient {
    /**
     * @notice Calculates the tokens needed to create multiple Protected Units
     * @param protectedUnits List of Protected Unit contracts to mint from
     * @param amounts How many tokens to mint from each contract
     * @return dsAmounts List of DS token amounts needed
     * @return paAmounts List of PA token amounts needed
     * @dev Recommended to keep the number of Protected Units under 10 to avoid gas issues
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
     * @param params All parameters needed for batch minting:
     *        - deadline: Time until which the transaction is valid
     *        - protectedUnits: List of Protected Unit contracts
     *        - amounts: How many tokens to mint from each contract
     *        - rawDsPermitSigs: Permission signatures for DS tokens
     *        - rawPaPermitSigs: Permission signatures for PA tokens
     * @return dsAmounts List of DS token amounts used
     * @return paAmounts List of PA token amounts used
     * @dev Recommended to keep the number of Protected Units under 10 to avoid gas issues
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
     * @notice Calculates the tokens you'll receive for burning multiple Protected Units
     * @param protectedUnits List of Protected Unit contracts to burn
     * @param amounts How many tokens to burn from each contract
     * @return dsAmounts List of DS token amounts you'll receive
     * @return paAmounts List of PA token amounts you'll receive
     * @return raAmounts List of RA token amounts you'll receive
     * @dev Recommended to keep the number of Protected Units under 10 to avoid gas issues
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
     * @param protectedUnits List of Protected Unit contracts to burn from
     * @param amounts How many tokens to burn from each contract
     * @return dsAdds List of DS token addresses
     * @return paAdds List of PA token addresses
     * @return raAdds List of RA token addresses
     * @return dsAmounts List of DS token amounts received
     * @return paAmounts List of PA token amounts received
     * @return raAmounts List of RA token amounts received
     * @dev Recommended to keep the number of Protected Units under 10 to avoid gas issues
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
     * @param amounts How many tokens to burn from each contract
     * @param permits List of permission parameters for each burn
     * @return dsAdds List of DS token addresses
     * @return paAdds List of PA token addresses
     * @return raAdds List of RA token addresses
     * @return dsAmounts List of DS token amounts received
     * @return paAmounts List of PA token amounts received
     * @return raAmounts List of RA token amounts received
     * @dev Recommended to keep the number of Protected Units under 10 to avoid gas issues
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
