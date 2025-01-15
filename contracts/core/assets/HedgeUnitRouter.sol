// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {HedgeUnit} from "./HedgeUnit.sol";
import {IHedgeUnitRouter} from "../../interfaces/IHedgeUnitRouter.sol";
import {MinimalSignatureHelper, Signature} from "./../../libraries/SignatureHelperLib.sol";

/**
 * @title HedgeUnitRouter
 * @notice This contract is used to execute batch mint and batch dissolve functions for multiple HedgeUnit contracts.
 */
contract HedgeUnitRouter is IHedgeUnitRouter, AccessControl, ReentrancyGuardTransient {
    string public constant DS_PERMIT_BATCH_MINT_FUNCTION_TYPEHASH = "DS_PERMIT_BATCH_MINT_FUNCTION_TYPEHASH";

    // this role will be assigned through grantRole function
    bytes32 public constant HEDGE_UNIT_FACTORY_ROLE = keccak256("HEDGE_UNIT_FACTORY_ROLE");

    modifier onlyDefaultAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotDefaultAdmin();
        }
        _;
    }

    modifier onlyHedgeUnitFactory() {
        if (!hasRole(HEDGE_UNIT_FACTORY_ROLE, msg.sender)) {
            revert CallerNotFactory();
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

        dsAmounts = new uint256[](hedgeUnits.length);
        paAmounts = new uint256[](hedgeUnits.length);

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < hedgeUnits.length; i++) {
            (dsAmounts[i], paAmounts[i]) = HedgeUnit(hedgeUnits[i]).previewMint(amounts[i]);
        }
    }

    // This function is used to batch mint multiple HedgeUnits in single transaction.
    function batchMint(BatchMintParams memory params)
        external
        nonReentrant
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts)
    {
        if (params.hedgeUnits.length != params.amounts.length) {
            revert InvalidInput();
        }

        dsAmounts = new uint256[](params.hedgeUnits.length);
        paAmounts = new uint256[](params.hedgeUnits.length);

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < params.hedgeUnits.length; i++) {
            bytes memory dsPermit = params.rawDsPermitSigs[i];
            bytes memory paPermit = params.rawPaPermitSigs[i];

            if (dsPermit.length != 0) {
                Signature memory signature = MinimalSignatureHelper.split(dsPermit);
            }

            (dsAmounts[i], paAmounts[i]) = HedgeUnit(params.hedgeUnits[i]).mint(
                params.minter, params.amounts[i], params.rawDsPermitSigs[i], params.rawPaPermitSigs[i], params.deadline
            );
        }
    }

    // This function is used to preview batch dissolve for multiple HedgeUnits in single transaction.
    function previewBatchDissolve(address[] calldata hedgeUnits, uint256[] calldata amounts)
        external
        view
        returns (uint256[] memory dsAmounts, uint256[] memory paAmounts, uint256[] memory raAmounts)
    {
        if (hedgeUnits.length != amounts.length) {
            revert InvalidInput();
        }

        dsAmounts = new uint256[](hedgeUnits.length);
        paAmounts = new uint256[](hedgeUnits.length);
        raAmounts = new uint256[](hedgeUnits.length);

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < hedgeUnits.length; i++) {
            (dsAmounts[i], paAmounts[i], raAmounts[i]) = HedgeUnit(hedgeUnits[i]).previewBurn(msg.sender, amounts[i]);
        }
    }

    // This function is used to dissolve multiple HedgeUnits in single transaction.
    function batchDissolve(address[] calldata hedgeUnits, uint256[] calldata amounts)
        external
        nonReentrant
        returns (address[] memory dsAdds, address[] memory paAdds, address[] memory raAdds, uint256[] memory dsAmounts, uint256[] memory paAmounts, uint256[] memory raAmounts)
    {
        if (hedgeUnits.length != amounts.length) {
            revert InvalidInput();
        }

        dsAmounts = new uint256[](hedgeUnits.length);
        paAmounts = new uint256[](hedgeUnits.length);
        raAmounts = new uint256[](hedgeUnits.length);
        dsAdds = new address[](hedgeUnits.length);
        paAdds = new address[](hedgeUnits.length);
        raAdds = new address[](hedgeUnits.length);            

        // If large number of HedgeUnits are passed, this function will revert due to gas limit.
        // So we will keep the limit to 10 HedgeUnits(or even less if needed) from frontend.
        for (uint256 i = 0; i < hedgeUnits.length; i++) {
            if (!isHedgeUnit[hedgeUnits[i]]) {
                revert InvalidInput();
            }
            (dsAdds[i], paAdds[i], raAdds[i], dsAmounts[i], paAmounts[i], raAmounts[i]) = HedgeUnit(hedgeUnits[i]).dissolve(msg.sender, amounts[i]);
        }
    }
}
