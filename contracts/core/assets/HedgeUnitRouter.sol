// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {HedgeUnit} from "./HedgeUnit.sol";
import {IHedgeUnitRouter} from "../../interfaces/IHedgeUnitRouter.sol";
import {MinimalSignatureHelper, Signature} from "./../../libraries/SignatureHelperLib.sol";

/**
 * @title HedgeUnitRouter
 * @notice This contract is used to execute batch mint and batch burn functions for multiple HedgeUnit contracts.
 */
contract HedgeUnitRouter is IHedgeUnitRouter, AccessControl, ReentrancyGuardTransient {
    modifier onlyDefaultAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotDefaultAdmin();
        }
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // This function is used to preview batch mint for multiple HedgeUnits in single transaction.
    function previewBatchMint(address[] calldata hedgeUnits, uint256[] calldata amounts)
        external
        view
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts)
    {
        if (hedgeUnits.length != amounts.length) {
            revert InvalidInput();
        }
        uint256 length = hedgeUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            (dsAmounts[i], paAmounts[i]) = HedgeUnit(hedgeUnits[i]).previewMint(amounts[i]);
        }
    }

    // This function is used to batch mint multiple HedgeUnits in single transaction.
    function batchMint(BatchMintParams calldata params)
        external
        nonReentrant
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts)
    {
        if (params.hedgeUnits.length != params.amounts.length) {
            revert InvalidInput();
        }
        uint256 length = params.hedgeUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            (dsAmounts[i], paAmounts[i]) = HedgeUnit(params.hedgeUnits[i]).mint(
                msg.sender, params.amounts[i], params.rawDsPermitSigs[i], params.rawPaPermitSigs[i], params.deadline
            );
        }
    }

    // This function is used to preview batch burn for multiple HedgeUnits in single transaction.
    function previewBatchBurn(address[] calldata hedgeUnits, uint256[] calldata amounts)
        external
        view
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts, uint256[] memory raAmounts)
    {
        if (hedgeUnits.length != amounts.length) {
            revert InvalidInput();
        }
        uint256 length = hedgeUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);
        raAmounts = new uint256[](length);

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            (dsAmounts[i], paAmounts[i], raAmounts[i]) = HedgeUnit(hedgeUnits[i]).previewBurn(msg.sender, amounts[i]);
        }
    }

    // This function is used to burn multiple HedgeUnits in single transaction.
    function batchBurn(address[] calldata hedgeUnits, uint256[] calldata amounts)
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
        (paAdds, dsAdds, raAdds, dsAmounts, paAmounts, raAmounts) = _batchBurn(hedgeUnits, amounts);
    }

    // This function is used to burn multiple HedgeUnits in single transaction with permits
    function batchBurn(
        address[] calldata hedgeUnits,
        uint256[] calldata amounts,
        IHedgeUnitRouter.BatchBurnPermitParams[] calldata permits
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
            HedgeUnit hedgeUnit = HedgeUnit(hedgeUnits[i]);
            IHedgeUnitRouter.BatchBurnPermitParams calldata permit = permits[i];

            Signature memory signature = MinimalSignatureHelper.split(permit.rawHedgeUnitPermitSig);

            hedgeUnit.permit(
                permit.owner, permit.spender, permit.value, permit.deadline, signature.v, signature.r, signature.s
            );
        }

        (paAdds, dsAdds, raAdds, dsAmounts, paAmounts, raAmounts) = _batchBurn(hedgeUnits, amounts);
    }

    function _batchBurn(address[] calldata hedgeUnits, uint256[] calldata amounts)
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
        if (hedgeUnits.length != amounts.length) {
            revert InvalidInput();
        }
        uint256 length = hedgeUnits.length;

        dsAmounts = new uint256[](length);
        paAmounts = new uint256[](length);
        raAmounts = new uint256[](length);
        dsAdds = new address[](length);
        paAdds = new address[](length);
        raAdds = new address[](length);

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < length; ++i) {
            HedgeUnit hedgeUnit = HedgeUnit(hedgeUnits[i]);

            dsAdds[i] = hedgeUnit.latestDs();
            paAdds[i] = address(hedgeUnit.PA());
            raAdds[i] = address(hedgeUnit.RA());

            (dsAmounts[i], paAmounts[i], raAmounts[i]) = hedgeUnit.previewBurn(msg.sender, amounts[i]);

            HedgeUnit(hedgeUnits[i]).burnFrom(msg.sender, amounts[i]);
        }
    }
}
