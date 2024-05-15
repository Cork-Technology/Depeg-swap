// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct VaultConfig {
    // 1 % = 1e18
    uint256 fee;
    // 1 % = 1e18
    uint256 waConvertThreshold;
    // 1 % = 1e18
    uint256 ammDepositThreshold;
    uint256 ammWaBalance;
}

library VaultConfigLibrary {
    function initialize(
        uint256 fee,
        uint256 waConvertThreshold,
        uint256 ammDepositThreshold,
        uint256 ammWaBalance
    ) internal pure returns (VaultConfig memory) {
        return
            VaultConfig({
                fee: fee,
                waConvertThreshold: waConvertThreshold,
                ammDepositThreshold: ammDepositThreshold,
                ammWaBalance: ammWaBalance
            });
    }

    function updateFee(VaultConfig memory self, uint256 fee) internal pure {
        self.fee = fee;
    }

    function updateWaConvertThreshold(
        VaultConfig memory self,
        uint256 waConvertThreshold
    ) internal pure {
        self.waConvertThreshold = waConvertThreshold;
    }

    function updateAmmDepositThreshold(
        VaultConfig memory self,
        uint256 ammDepositThreshold
    ) internal pure {
        self.ammDepositThreshold = ammDepositThreshold;
    }

    function increaseAmmWaBalance(
        VaultConfig memory self,
        uint256 amount
    ) internal pure {
        self.ammWaBalance += amount;
    }

    function calcWa(
        VaultConfig memory self,
        uint256 amount
    ) internal pure returns (uint256 locked, uint256 free) {
        locked = amount - (amount * self.waConvertThreshold) / 1e20;
        free = amount - locked;
    }
}
