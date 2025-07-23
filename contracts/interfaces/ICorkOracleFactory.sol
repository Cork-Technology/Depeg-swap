// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC4626} from "./IERC4626.sol";
import {CompositePriceFeed} from "../oracles/CompositePriceFeed.sol";
import {PriceFeedParams} from "./ICompositePriceFeed.sol";
import {IErrors} from "./IErrors.sol";

enum CorkOracleType {
    NONE,
    PRICE_FEED,
    LINEAR_DISCOUNT
}

/**
 * @title ICorkOracleFactory Interface
 * @author Cork Team
 * @notice Interface which provides common errors, events and functions for CT Oracle Factory contract
 */
interface ICorkOracleFactory is IErrors {
    /// @notice The metadata of the oracle.
    struct OracleMetadata {
        CorkOracleType oracleType;
    }

    /// @notice Thrown when a oracle creation fails.
    error OracleCreationFailed();

    /// @notice Emitted when a new Composite price feed oracle is created.
    /// @param oracle The address of the Composite price feed oracle.
    /// @param caller The caller of the function.
    /// @param salt The salt used for the creation of the oracle.
    event CreateCompositePriceFeedV1(address caller, address oracle, bytes32 salt);

    /// @notice Emitted when a new Linear discount oracle is created.
    /// @param oracle The address of the Linear discount oracle.
    /// @param caller The caller of the function.
    /// @param salt The salt used for the creation of the oracle.
    event CreateLinearDiscountOracleV1(address caller, address oracle, bytes32 salt);

    /// @notice Whether an oracle was created with the factory.
    function isCorkOracle(address target) external view returns (bool);

    /// @notice Whether a feed (push-based oracle) was created with the factory.
    function isCorkPriceFeed(address target) external view returns (bool);

    /// @dev Here is the list of assumptions that guarantees the oracle behaves as expected:
    /// - The vaults, if set, are ERC4626-compliant.
    /// - The feeds, if set, are Chainlink-interface-compliant.
    /// - Decimals passed as argument are correct.
    /// - The base vaults's sample shares quoted as assets and the base feed prices don't overflow when multiplied.
    /// - The quote vault's sample shares quoted as assets and the quote feed prices don't overflow when multiplied.
    /// baseVault Base vault. Pass address zero to omit this parameter.
    /// baseVaultConversionSample The sample amount of base vault shares used to convert to underlying.
    /// Pass 1 if the base asset is not a vault. Should be chosen such that converting `baseVaultConversionSample` to
    /// assets has enough precision.
    /// baseFeed1 First base feed. Pass address zero if the price = 1.
    /// baseFeed2 Second base feed. Pass address zero if the price = 1.
    /// baseTokenDecimals Base token decimals.
    /// quoteVault Quote vault. Pass address zero to omit this parameter.
    /// quoteVaultConversionSample The sample amount of quote vault shares used to convert to underlying.
    /// Pass 1 if the quote asset is not a vault. Should be chosen such that converting `quoteVaultConversionSample` to
    /// assets has enough precision.
    /// quoteFeed1 First quote feed. Pass address zero if the price = 1.
    /// quoteFeed2 Second quote feed. Pass address zero if the price = 1.
    /// quoteTokenDecimals Quote token decimals.
    /// @param salt The salt to use for the CREATE2.
    /// @dev The base asset should be the collateral token and the quote asset the loan token.
    function createCompositePriceFeed(PriceFeedParams[] calldata params, bytes32 salt)
        external
        returns (CompositePriceFeed oracle);
}
