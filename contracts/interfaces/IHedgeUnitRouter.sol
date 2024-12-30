pragma solidity ^0.8.24;

interface IHedgeUnitRouter {
    event HedgeUnitSet(address hedgeUnit);

    // This error occurs when user passes invalid input to the function.
    error InvalidInput();

    error CallerNotFactory();

    error HedgeUnitExists();

    error NotDefaultAdmin();

    // Read functions
    /**
     * @notice Adds new HedgeUnit contract address to hedgeUnit Router
     * @param hedgeUnitAdd new Hedge Unit contract address
     */
    function addHedgeUnit(address hedgeUnitAdd) external;
}
