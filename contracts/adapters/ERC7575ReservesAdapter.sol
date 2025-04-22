// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC4626} from "../interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";

contract ERC7575ReservesAdapter is IERC4626 {
    IUniswapV2Pair public immutable share;
    address public immutable asset;

    bool internal immutable isToken0;

    /// @notice Constructs the asset adapter for a given share token
    /// @param _share The address of the share token
    /// @param _asset The address of the underlying or backing asset
    constructor(IUniswapV2Pair _share, address _asset) {
        address token0 = _share.token0();
        address token1 = _share.token1();
        if (_asset != token0 && _asset != token1) revert("Asset not found");

        isToken0 = (_asset == token0);
        share = _share;
        asset = _asset;
    }

    /// @notice Returns the total amount of reserves
    /// @return totalAssets The total amount of reserves
    function totalAssets() public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = share.getReserves();
        return (isToken0 ? uint256(reserve0) : uint256(reserve1));
    }

    /// @notice Returns the amount of reserves proportional to the given shares
    /// @param shares The amount of share tokens
    /// @return assets The amount of reserves
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 totalShares = share.totalSupply();
        return totalShares == 0 ? 0 : totalAssets() * shares / totalShares; // floor division
    }
}
