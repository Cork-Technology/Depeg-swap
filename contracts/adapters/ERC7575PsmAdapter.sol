// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ModuleCore} from "../core/ModuleCore.sol";
import {Asset as CorkToken} from "../core/assets/Asset.sol";
import {Id} from "../libraries/Pair.sol";
import {IERC7575Adapter} from "../interfaces/adapters/IERC7575Adapter.sol";

/**
 * @title ERC7575PsmAdapter
 * @author Cork Team
 * @notice ERC7575 standard adapter for PSM
 */
contract ERC7575PsmAdapter is IERC7575Adapter {
    /// @notice The share token.
    CorkToken public immutable SHARE;
    /// @notice The underlying backing asset.
    address public immutable ASSET;
    /// @notice Whether the asset is the RA.
    bool internal immutable IS_TOKEN_RA;
    /// @notice The market ID in module core.
    Id internal immutable MARKET_ID;
    /// @notice The module core contract.
    ModuleCore internal immutable MODULE_CORE;

    /// @notice Constructs the asset adapter for a given share token
    /// @param share The address of the share token
    /// @param asset The address of the underlying or backing asset
    /// @param marketId The market ID in module core
    /// @param moduleCore The module core contract
    constructor(CorkToken share, address asset, Id marketId, ModuleCore moduleCore) {
        (address pa, address ra,,,) = moduleCore.markets(marketId);
        if (asset != ra && asset != pa) revert AssetNotFound();

        IS_TOKEN_RA = (asset == ra);
        MARKET_ID = marketId;
        MODULE_CORE = moduleCore;
        SHARE = share;
        ASSET = asset;
    }

    /// @notice Returns the total amount of reserves
    /// @return totalAssets The total amount of reserves
    function totalAssets() public view returns (uint256 totalAssets) {
        uint256 marketEpoch = MODULE_CORE.lastDsId(MARKET_ID);
        uint256 ctEpoch = SHARE.dsId();

        totalAssets = (marketEpoch == ctEpoch)
            ? MODULE_CORE.valueLocked(MARKET_ID, IS_TOKEN_RA)
            : MODULE_CORE.valueLocked(MARKET_ID, ctEpoch, IS_TOKEN_RA);
    }

    /// @notice Returns the amount of reserves proportional to the given shares
    /// @param shares The amount of share tokens
    /// @return assets The amount of reserves
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        uint256 totalShares = SHARE.totalSupply();
        assets = totalShares == 0 ? 0 : totalAssets() * shares / totalShares; // floor division
    }
}
