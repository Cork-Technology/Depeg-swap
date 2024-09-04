pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev PeggedAsset structure for PA(Pegged Assets)    
 */
struct PeggedAsset {
    address _address;
}

/**
 * @title PeggedAssetLibrary Contract
 * @author Cork Team
 * @notice PeggedAsset Library which implements functions for Pegged assets
 */
library PeggedAssetLibrary {
    using PeggedAssetLibrary for PeggedAsset;
    using SafeERC20 for IERC20;

    function asErc20(PeggedAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }
}
