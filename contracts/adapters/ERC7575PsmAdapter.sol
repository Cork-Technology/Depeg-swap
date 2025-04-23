// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC4626} from "../interfaces/IERC4626.sol";
import {ModuleCore} from "../core/ModuleCore.sol";
import {Asset as CorkToken} from "../core/assets/Asset.sol";
import {Id} from "../libraries/Pair.sol";

contract ERC7575PsmAdapter is IERC4626 {
    CorkToken public immutable SHARE;
    address public immutable ASSET;
    bool internal immutable IS_TOKEN_RA;
    Id internal immutable MARKET_ID;
    ModuleCore internal immutable MODULE_CORE;

    /// @notice Error thrown when the asset is not found
    error AssetNotFound();

    /// @notice Constructs the asset adapter for a given share token
    /// @param _share The address of the share token
    /// @param _asset The address of the underlying or backing asset
    constructor(CorkToken _share, address _asset, Id _marketId, ModuleCore _moduleCore) {
        (address pa, address ra,,,) = _moduleCore.markets(_marketId);
        if (_asset != ra && _asset != pa) revert AssetNotFound();

        IS_TOKEN_RA = (_asset == ra);
        MARKET_ID = _marketId;
        MODULE_CORE = _moduleCore;
        SHARE = _share;
        ASSET = _asset;
    }

    /// @notice Returns the total amount of reserves
    /// @return totalAssets The total amount of reserves
    function totalAssets() public view returns (uint256) {
        uint256 marketEpoch = MODULE_CORE.lastDsId(MARKET_ID);
        uint256 ctEpoch = SHARE.dsId();

        return (marketEpoch == ctEpoch)
            ? MODULE_CORE.valueLocked(MARKET_ID, IS_TOKEN_RA)
            : MODULE_CORE.valueLocked(MARKET_ID, ctEpoch, IS_TOKEN_RA);
    }

    /// @notice Returns the amount of reserves proportional to the given shares
    /// @param shares The amount of share tokens
    /// @return assets The amount of reserves
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 totalShares = SHARE.totalSupply();
        return totalShares == 0 ? 0 : totalAssets() * shares / totalShares; // floor division
    }
}
