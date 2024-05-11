// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./../DepegSwap.sol";
import "./../CoverToken.sol";

struct DepegSwap {
    address depegSwap;
    address coverToken;
    uint256 expiryTimestamp;
}

library DepegSwapLibrary {
    function isExpired(DepegSwap memory self) internal view returns (bool) {
        return block.timestamp >= self.expiryTimestamp;
    }

    function isInitialized(DepegSwap memory self) internal pure returns (bool) {
        return self.depegSwap != address(0) && self.coverToken != address(0);
    }

    function initialize(
        string memory pairName,
        uint256 expiry
    ) internal returns (DepegSwap memory) {
        return
            DepegSwap({
                depegSwap: address(new DepegSwapContract(pairName)),
                coverToken: address(new CoverTokenContract(pairName)),
                expiryTimestamp: expiry
            });
    }

    function totalSupply(DepegSwap memory self) internal view returns (uint256) {
        return DepegSwapContract(self.depegSwap).totalSupply();
    }

    function issue(DepegSwap memory self, address to, uint256 amount) internal {
        DepegSwapContract(self.depegSwap).mint(to, amount);
        CoverTokenContract(self.coverToken).mint(to, amount);
    }
}
