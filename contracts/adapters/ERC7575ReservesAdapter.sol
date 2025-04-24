// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IERC7575Adapter} from "../interfaces/adapters/IERC7575Adapter.sol";

/**
 * @title ERC7575ReservesAdapter
 * @author Cork Team
 * @notice ERC7575 standard adapter for reserves
 */
contract ERC7575ReservesAdapter is IERC7575Adapter {
    /// @notice The share token Pair.
    IUniswapV2Pair public immutable SHARE;
    /// @notice The underlying backing asset.
    address public immutable ASSET;
    /// @notice Whether the asset is the token0.
    bool internal immutable IS_TOKEN_0;

    /// @notice Constructs the asset adapter for a given share token
    /// @param share The address of the share token
    /// @param asset The address of the underlying or backing asset
    constructor(IUniswapV2Pair share, address asset) {
        address token0 = share.token0();
        address token1 = share.token1();
        if (asset != token0 && asset != token1) revert AssetNotFound();

        IS_TOKEN_0 = (asset == token0);
        SHARE = share;
        ASSET = asset;
    }

    /// @notice Returns the total amount of reserves
    /// @return totalAssets The total amount of reserves
    function totalAssets() public view returns (uint256 totalAssets) {
        (uint112 reserve0, uint112 reserve1,) = SHARE.getReserves();
        totalAssets = IS_TOKEN_0 ? uint256(reserve0) : uint256(reserve1);
    }

    /// @notice Returns the amount of reserves proportional to the given shares
    /// @param shares The amount of share tokens
    /// @return assets The amount of reserves
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        uint256 totalShares = SHARE.totalSupply();
        assets = totalShares == 0 ? 0 : totalAssets() * shares / totalShares; // floor division
    }
}
