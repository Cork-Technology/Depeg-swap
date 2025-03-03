// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ProtectedUnit} from "./ProtectedUnit.sol";
import {IProtectedUnitRouter} from "../../interfaces/IProtectedUnitRouter.sol";
import {MinimalSignatureHelper, Signature} from "./../../libraries/SignatureHelperLib.sol";

/**
 * @title ProtectedUnitRouter
 * @notice This contract is used to execute batch mint and batch burn functions for multiple ProtectedUnit contracts.
 */
contract ProtectedUnitRouter is IProtectedUnitRouter, ReentrancyGuardTransient {
    // This function is used to preview batch mint for multiple ProtectedUnits in single transaction.
    /**
     * @notice Previews the batch minting of protected units.
     * @dev This function will revert if the number of protected units and amounts do not match.
     *      If a large number of protected units are passed, this function may revert due to gas limits.
     *      It is recommended to limit the number of protected units to 10 or fewer from the frontend.
     * @param protectedUnits An array of addresses of the protected units to be minted.
     * @param amounts An array of amounts corresponding to each protected unit to be minted.
     * @return dsAmounts An array of amounts for the DS tokens to be minted.
     * @return paAmounts An array of amounts for the PA tokens to be minted.
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

    // This function is used to batch mint multiple ProtectedUnits in single transaction.
    /**
     * @notice Mints multiple ProtectedUnits in a single transaction.
     * @dev This function will revert if the number of ProtectedUnits is too large due to gas limits.
     *      It is recommended to limit the number of ProtectedUnits to 10 or fewer from the frontend.
     * @param params The parameters for batch minting, including:
     *               - protectedUnits: An array of ProtectedUnit addresses to mint.
     *               - amounts: An array of amounts to mint for each ProtectedUnit.
     *               - rawDsPermitSigs: An array of raw DS permit signatures.
     *               - rawPaPermitSigs: An array of raw PA permit signatures.
     *               - deadline: The deadline for the permit signatures.
     * @return dsAmounts An array of minted DS amounts for each ProtectedUnit.
     * @return paAmounts An array of minted PA amounts for each ProtectedUnit.
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

    // This function is used to preview batch burn for multiple ProtectedUnits in single transaction.
    /**
     * @notice Previews the batch burn of protected units.
     * @dev This function will revert if the number of protected units exceeds the gas limit.
     *      Ensure the limit is kept to 10 protected units or less from the frontend.
     * @param protectedUnits An array of addresses of the protected units to be burned.
     * @param amounts An array of amounts corresponding to each protected unit to be burned.
     * @return dsAmounts An array of amounts in DS tokens that will be received for each protected unit.
     * @return paAmounts An array of amounts in PA tokens that will be received for each protected unit.
     * @return raAmounts An array of amounts in RA tokens that will be received for each protected unit.
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

    // This function is used to burn multiple ProtectedUnits in single transaction.
    /**
     * @notice Burns multiple protected units in a batch.
     * @dev This function is non-reentrant.
     * @param protectedUnits An array of addresses representing the protected units to be burned.
     * @param amounts An array of uint256 values representing the amounts of each protected unit to be burned.
     * @return dsAdds An array of addresses representing the destination addresses.
     * @return paAdds An array of addresses representing the protected asset addresses.
     * @return raAdds An array of addresses representing the return asset addresses.
     * @return dsAmounts An array of uint256 values representing the amounts for destination addresses.
     * @return paAmounts An array of uint256 values representing the amounts for protected asset addresses.
     * @return raAmounts An array of uint256 values representing the amounts for return asset addresses.
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

    // This function is used to burn multiple ProtectedUnits in single transaction with permits
    /**
     * @notice Burns multiple protected units in a batch process.
     * @dev This function allows the caller to burn multiple protected units by providing the necessary permits.
     * @param protectedUnits An array of addresses of the protected units to be burned.
     * @param amounts An array of amounts corresponding to each protected unit to be burned.
     * @param permits An array of permit parameters required for each protected unit.
     * @return dsAdds An array of addresses for the destination addresses.
     * @return paAdds An array of addresses for the protected unit addresses.
     * @return raAdds An array of addresses for the return addresses.
     * @return dsAmounts An array of amounts for the destination amounts.
     * @return paAmounts An array of amounts for the protected unit amounts.
     * @return raAmounts An array of amounts for the return amounts.
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
