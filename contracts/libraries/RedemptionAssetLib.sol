// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct RedemptionAsset {
    address _address;
}

library RedemptionAssetLibrary {
    using RedemptionAssetLibrary for RedemptionAsset;

    function asErc20(RedemptionAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }

    function psmBalance(RedemptionAsset memory self) internal view returns (uint256 balance) {
        balance = self.asErc20().balanceOf(address(this));
    }

    function redeemUnchecked(RedemptionAsset memory self, address from, uint256 amount) internal {
        self.asErc20().transferFrom(from, address(this), amount);
    }
}