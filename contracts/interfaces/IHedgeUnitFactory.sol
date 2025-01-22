pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";

interface IHedgeUnitFactory {
    // Event emitted when a new HedgeUnit contract is deployed
    event HedgeUnitDeployed(Id indexed pairId, address pa, address ra, address indexed hedgeUnitAddress);

    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    error HedgeUnitExists();

    error InvalidPairId();

    error NotConfig();
}