pragma solidity ^0.8.24;

interface IMathError {
    /// @notice no sane root is found when calculating value for buying DS
    error InvalidS();

    /// @notice no sane upper interval is found when trying to calculate value for buying DS
    error NoSignChange();

    /// @notice bisection method fail to converge after max iterations(256)
    error NoConverge();

    /// @notice invalid parameter
    error InvalidParam();

    /// @notice thrown when Reserve is Zero
    error ZeroReserve();

    /// @notice thrown when Input amount is not sufficient
    error InsufficientInputAmount();

    /// @notice thrown when not having sufficient Liquidity
    error InsufficientLiquidity();

    /// @notice thrown when Output amount is not sufficient
    error InsufficientOutputAmount();

    /// @notice thrown when the number is too big
    error TooBig();
}
