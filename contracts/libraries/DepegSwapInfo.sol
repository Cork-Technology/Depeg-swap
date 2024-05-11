// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct DepegSwapInfo {
    address depegSwap;
    address coverToken;
    uint256 expiryTimestamp;
}

library DepegSwapLibrary {
    function isExpired(DepegSwapInfo memory self) internal view returns (bool) {
        return block.timestamp >= self.expiryTimestamp;
    }

    function isInitialized(DepegSwapInfo memory self) internal pure returns (bool) {
        return self.depegSwap != address(0) && self.coverToken != address(0);
    }

    
}
