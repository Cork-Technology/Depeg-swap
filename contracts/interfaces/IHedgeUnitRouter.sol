pragma solidity ^0.8.24;

interface IHedgeUnitRouter {
    struct BatchMintParams {
        address minter;
        uint256 deadline;
        address[] hedgeUnits;
        uint256[] amounts;
        bytes[] rawDsPermitSigs;
        bytes[] rawPaPermitSigs;
    }

    struct BatchBurnPermitParams {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        bytes rawHedgeUnitPermitSig;
    }

    event HedgeUnitSet(address hedgeUnit);

    event HedgeUnitRemoved(address hedgeUnit);

    // This error occurs when user passes invalid input to the function.
    error InvalidInput();

    error CallerNotFactory();

    error HedgeUnitExists();

    error HedgeUnitNotExists();

    error NotDefaultAdmin();
}
