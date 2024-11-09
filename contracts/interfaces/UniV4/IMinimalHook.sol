pragma solidity ^0.8.0;

import "./IErrors.sol";
import "Cork-Hook/lib/MarketSnapshot.sol";

interface ICorkHook is IErrors {
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        returns (uint256 amountIn);
    function addLiquidity(
        address ra,
        address ct,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt, uint256 mintedLp);

    function removeLiquidity(
        address ra,
        address ct,
        uint256 liquidityAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt);

    function getLiquidityToken(address ra, address ct) external view returns (address);

    function getReserves(address ra, address ct) external view returns (uint256, uint256);

    function getFee(address ra, address ct)
        external
        view
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage);

    function getAmountIn(address ra, address ct, bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    function getAmountOut(address ra, address ct, bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function getPoolManager() external view returns (address);

    function getForwarder() external view returns (address);

    function getMarketSnapshot(address ra, address ct) external view returns (MarketSnapshot memory);
}
