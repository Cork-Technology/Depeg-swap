pragma solidity 0.8.24;

import {Signature, MinimalSignatureHelper} from "./SignatureHelperLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev PsmRedemptionAssetManager structure for Redemption Manager    
 */
struct PsmRedemptionAssetManager {
    address _address;
    uint256 locked;
    uint256 free;
}

/**
 * @title RedemptionAssetManagerLibrary Contract
 * @author Cork Team
 * @notice RedemptionAssetManager Library implements functions for RA(Redemption Assets) contract
 */
library RedemptionAssetManagerLibrary {
    using MinimalSignatureHelper for Signature;
    using SafeERC20 for IERC20;

    function initialize(address ra) internal pure returns (PsmRedemptionAssetManager memory) {
        return PsmRedemptionAssetManager(ra, 0, 0);
    }

    function reset(PsmRedemptionAssetManager storage self) internal {
        self.locked = 0;
        self.free = 0;
    }

    function incLocked(PsmRedemptionAssetManager storage self, uint256 amount) internal {
        self.locked = self.locked + amount;
    }

    function convertAllToFree(PsmRedemptionAssetManager storage self) internal returns (uint256) {
        if (self.locked == 0) {
            return self.free;
        }

        self.free = self.free + self.locked;
        self.locked = 0;

        return self.free;
    }

    function tryConvertAllToFree(PsmRedemptionAssetManager storage self) internal view returns (uint256) {
        if (self.locked == 0) {
            return self.free;
        }

        return self.free + self.locked;
    }

    function decLocked(PsmRedemptionAssetManager storage self, uint256 amount) internal {
        self.locked = self.locked - amount;
    }

    function lockFrom(PsmRedemptionAssetManager storage self, uint256 amount, address from) internal {
        incLocked(self, amount);
        lockUnchecked(self, amount, from);
    }

    function lockUnchecked(PsmRedemptionAssetManager storage self, uint256 amount, address from) internal {
        IERC20(self._address).safeTransferFrom(from, address(this), amount);
    }

    function unlockTo(PsmRedemptionAssetManager storage self, address to, uint256 amount) internal {
        decLocked(self, amount);
        unlockToUnchecked(self, amount, to);
    }

    function unlockToUnchecked(PsmRedemptionAssetManager storage self, uint256 amount, address to) internal {
        IERC20(self._address).safeTransfer(to, amount);
    }
}
