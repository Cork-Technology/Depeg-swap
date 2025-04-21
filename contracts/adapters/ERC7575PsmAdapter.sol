// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC4626} from "../interfaces/IERC4626.sol";
import {ModuleCore} from "../core/ModuleCore.sol";
import {Asset as CorkToken} from "../core/assets/Asset.sol";
import {Id} from "../libraries/Pair.sol";

contract ERC7575PsmAdapter is IERC4626 {
    CorkToken public immutable share;
    address public immutable asset;

    bool internal immutable isTokenRa;
    Id internal immutable marketId;
    ModuleCore internal immutable moduleCore;

    /// @notice Constructs the asset adapter for a given share token
    /// @param _shareToken The address of the share token
    /// @param _asset The address of the underlying or backing asset
    constructor(CorkToken _share, address _asset, Id _marketId, ModuleCore _moduleCore) {
        (address pa, address ra, ) = _moduleCore.markets(_marketId);
        if (_asset != ra && _asset != pa) revert("Asset not found");

        isTokenRa = (_asset == ra);
        marketId = _marketId;
        moduleCore = _moduleCore;
        share = _share;
        asset = _asset;
    }

    /// @notice Returns the total amount of reserves
    /// @return totalAssets The total amount of reserves
    function totalAssets() public view returns (uint256) {
        uint256 marketEpoch = moduleCore.lastDsId(marketId);
        uint256 ctEpoch = share.dsId();

        return (marketEpoch == ctEpoch) ?
            moduleCore.valueLocked(marketId, isTokenRa) :
            moduleCore.valueLocked(marketId, ctEpoch, isTokenRa);
    }

    /// @notice Returns the amount of reserves proportional to the given shares
    /// @param shares The amount of share tokens
    /// @return assets The amount of reserves
    function convertToAssets(uint256 shares) public view returns (uint256)
        uint256 totalShares = shareToken.totalSupply();
        return totalShares == 0 ? 0 : totalAssets() * shares / totalShares; // floor division
    }
}