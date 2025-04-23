// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import {ICompositePriceFeed, PriceFeedParams} from "../interfaces/ICompositePriceFeed.sol";
import {MinimalAggregatorV3Interface} from "../interfaces/MinimalAggregatorV3Interface.sol";

import {ErrorsLib} from "../libraries/oracles/ErrorsLib.sol";
import {IERC4626, VaultLib} from "../libraries/oracles/VaultLib.sol";
import {AggregatorV3Interface, ChainlinkDataFeedLib} from "../libraries/oracles/ChainlinkDataFeedLib.sol";

/// @title CompositePriceFeed
/// @author Cork Team
/// @custom:contact security@cork.tech
/// @notice Push oracle using Chainlink-compliant and ERC4626-compliant feeds.
contract CompositePriceFeed is ICompositePriceFeed {
    using Math for uint256;
    using VaultLib for IERC4626;
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    /* IMMUTABLES or STORAGE */

    PriceFeedParams[] internal _FEED_PARAMS;

    /// @inheritdoc ICompositePriceFeed
    uint256[] public SCALE_FACTORS;

    /* CONSTRUCTOR */

    constructor(PriceFeedParams[] memory _params) {
        // The ERC4626 vault parameters are used to price their respective conversion samples of their respective
        // shares, so it requires multiplying by `QUOTE_VAULT_CONVERSION_SAMPLE` and dividing
        // by `BASE_VAULT_CONVERSION_SAMPLE` in the `SCALE_FACTOR` definition.

        for (uint256 i = 0; i < _params.length; ++i) {
            PriceFeedParams memory p = _params[i];

            // Verify that vault = address(0) => vaultConversionSample = 1 for each vault.
            require(
                address(p.baseVault) != address(0) || p.baseVaultConversionSample == 1,
                ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_NOT_ONE
            );
            require(
                address(p.quoteVault) != address(0) || p.quoteVaultConversionSample == 1,
                ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_NOT_ONE
            );
            require(p.baseVaultConversionSample != 0, ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_ZERO);
            require(p.quoteVaultConversionSample != 0, ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_ZERO);

            _FEED_PARAMS[i] = p;
            SCALE_FACTORS[i] = _scaleFactor(p);
        }
    }

        /// @inheritdoc ICompositePriceFeed
    function FEED_PARAMS(uint256 i) external view returns (PriceFeedParams memory){
        return _FEED_PARAMS[i];
    }

    /* PRICE */

    function price() public view returns (uint256 totalPrice) {
        for (uint256 i = 0; i < _FEED_PARAMS.length; ++i) {
            PriceFeedParams memory p = _FEED_PARAMS[i];
            totalPrice += SCALE_FACTORS[i].mulDiv(
                p.baseVault.getAssets(p.baseVaultConversionSample) * p.baseFeed1.getPrice() * p.baseFeed2.getPrice(),
                p.quoteVault.getAssets(p.quoteVaultConversionSample) * p.quoteFeed1.getPrice()
                    * p.quoteFeed2.getPrice()
            );
        }
    }

    /// @inheritdoc MinimalAggregatorV3Interface
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        answer = int256(price());
    }

    function decimals() public pure returns (uint8) {
        return 36;
    }

    function _scaleFactor(PriceFeedParams memory p) internal view returns (uint256) {
        // Expects `price()` to be the quantity of 1 asset Q1 that can be exchanged for 1 asset B1,
        // scaled by 1e36:
        // 1e36 * (pB1 * 1e(dB2 - dB1)) * (pB2 * 1e(dC - dB2)) / ((pQ1 * 1e(dQ2 - dQ1)) * (pQ2 * 1e(dC - dQ2)))
        // = 1e36 * (pB1 * 1e(-dB1) * pB2) / (pQ1 * 1e(-dQ1) * pQ2)

        // Let fpB1, fpB2, fpQ1, fpQ2 be the feed precision of the respective prices pB1, pB2, pQ1, pQ2.
        // Feeds return pB1 * 1e(fpB1), pB2 * 1e(fpB2), pQ1 * 1e(fpQ1) and pQ2 * 1e(fpQ2).

        // Based on the implementation of `price()` below, the value of `SCALE_FACTOR` should thus satisfy:
        // (pB1 * 1e(fpB1)) * (pB2 * 1e(fpB2)) * SCALE_FACTOR / ((pQ1 * 1e(fpQ1)) * (pQ2 * 1e(fpQ2)))
        // = 1e36 * (pB1 * 1e(-dB1) * pB2) / (pQ1 * 1e(-dQ1) * pQ2)

        // So SCALE_FACTOR = 1e36 * 1e(-dB1) * 1e(dQ1) * 1e(-fpB1) * 1e(-fpB2) * 1e(fpQ1) * 1e(fpQ2)
        //                 = 1e(36 + dQ1 + fpQ1 + fpQ2 - dB1 - fpB1 - fpB2)
        return 10
            ** (
                decimals() + p.quoteTokenDecimals + p.quoteFeed1.getDecimals() + p.quoteFeed2.getDecimals()
                    - p.baseTokenDecimals - p.baseFeed1.getDecimals() - p.baseFeed2.getDecimals()
            ) * p.quoteVaultConversionSample / p.baseVaultConversionSample;
    }
}
