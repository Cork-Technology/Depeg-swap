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
            (dsAmounts[i], paAmounts[i], raAmounts[i]) = ProtectedUnit(protectedUnits[i]).previewBurn(msg.sender, amounts[i]);
        }
    }

    // This function is used to burn multiple ProtectedUnits in single transaction.
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
