// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "../../v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../Asset.sol";
import "./DsSwapperMathLib.sol";

struct AssetPair {
    Asset ds;
    /// @dev [RA, CT]
    IUniswapV2Pair pair;
}
struct ReserveState {
    /// @dev dsId => [RA, CT, DS]
    mapping(uint256 => AssetPair) ds;
}

library DsFlashSwaplibrary {
    function onNewIssuance(
        ReserveState storage self,
        uint256 dsId,
        address ds,
        address pair
    ) internal {
        self.ds[dsId] = AssetPair(Asset(ds), IUniswapV2Pair(pair));
    }

    function getCurrentDsPrice(
        ReserveState storage self,
        uint256 dsId
    ) internal view returns (uint256 price) {
        (uint112 raReserve, uint112 ctReserve, ) = self
            .ds[dsId]
            .pair
            .getReserves();

        price = SwapperMathLibrary.calculateDsPrice(
            raReserve,
            ctReserve,
            self.ds[dsId].ds.exchangeRate()
        );
    }
}
