// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct VaultConfig {
    // 1 % = 1e18
    uint256 fee;
    //
    uint256 freeWaBalance;
    uint256 ammWaDepositThreshold;
    //
    uint256 ammCtDepositThreshold;
    uint256 freeCtBalance;
}

library VaultConfigLibrary {
    function initialize(
        uint256 fee,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold
    ) internal pure returns (VaultConfig memory) {
        return
            VaultConfig({
                fee: fee,
                ammWaDepositThreshold: ammWaDepositThreshold,
                freeWaBalance: 0,
                freeCtBalance: 0,
                ammCtDepositThreshold: ammCtDepositThreshold
            });
    }

    function mustProvideLiquidity(
        VaultConfig memory self
    ) internal pure returns (bool) {
        return
            (self.freeWaBalance > self.ammWaDepositThreshold) &&
            (self.freeCtBalance > self.ammCtDepositThreshold);
    }

    function updateFee(VaultConfig memory self, uint256 fee) internal pure {
        self.fee = fee;
    }

    function updateAmmDepositThreshold(
        VaultConfig memory self,
        uint256 ammDepositThreshold
    ) internal pure {
        self.ammWaDepositThreshold = ammDepositThreshold;
    }

    function increaseWaBalance(
        VaultConfig memory self,
        uint256 amount
    ) internal pure {
        self.freeWaBalance += amount;
    }

    function increaseCtBalance(
        VaultConfig memory self,
        uint256 amount
    ) internal pure {
        self.freeCtBalance += amount;
    }

    function decreaseAmmWaBalance(
        VaultConfig memory self,
        uint256 amount
    ) internal pure {
        self.freeWaBalance -= amount;
    }
}
