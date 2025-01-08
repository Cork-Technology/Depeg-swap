// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {HedgeUnit} from "./HedgeUnit.sol";
import {IHedgeUnitRouter} from "../../interfaces/IHedgeUnitRouter.sol";

/**
 * @title HedgeUnitRouter
 * @notice This contract is used to execute batch mint and batch dissolve functions for multiple HedgeUnit contracts.
 */
contract HedgeUnitRouter is IHedgeUnitRouter, AccessControl, ReentrancyGuardTransient {
    // this role will be assigned through grantRole function
    bytes32 public constant HEDGE_UNIT_FACTORY_ROLE = keccak256("HEDGE_UNIT_FACTORY_ROLE");

    // Mapping to keep track of legitimate HedgeUnit contracts
    mapping(address => bool) public isHedgeUnit;

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

    /**
     * @dev Adds new HedgeUnit contract address
     * @param hedgeUnitAdd new Hedge Unit contract address
     */
    function addHedgeUnit(address hedgeUnitAdd) external onlyHedgeUnitFactory {
        if (hedgeUnitAdd == address(0)) {
            revert InvalidInput();
        }
        if (isHedgeUnit[hedgeUnitAdd]) {
            revert HedgeUnitExists();
        }
        isHedgeUnit[hedgeUnitAdd] = true;
        emit HedgeUnitSet(hedgeUnitAdd);
    }

    /**
     * @dev Removes HedgeUnit contract address
     * @dev Note : this only removes hedge unit from this router, so hedge unit contract will still work even after if it gets removed from here
     * @dev Note : Generally this will be used on emergency situations only
     * @param hedgeUnitAdd old Hedge Unit contract address
     */
    function removeHedgeUnit(address hedgeUnitAdd) external onlyDefaultAdmin {
        if (hedgeUnitAdd == address(0)) {
            revert InvalidInput();
        }
        if (!isHedgeUnit[hedgeUnitAdd]) {
            revert HedgeUnitNotExists();
        }
        isHedgeUnit[hedgeUnitAdd] = false;
        emit HedgeUnitRemoved(hedgeUnitAdd);
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
            if (!isHedgeUnit[hedgeUnits[i]]) {
                revert InvalidInput();
            }
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
            if (!isHedgeUnit[params.hedgeUnits[i]]) {
                revert InvalidInput();
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
            if (!isHedgeUnit[hedgeUnits[i]]) {
                revert InvalidInput();
            }
            (dsAmounts[i], paAmounts[i], raAmounts[i]) =
                HedgeUnit(hedgeUnits[i]).previewDissolve(msg.sender, amounts[i]);
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
