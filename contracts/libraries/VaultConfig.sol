// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct VaultConfig {
    // 1 % = 1e18
    uint256 fee;
    // 1 % = 1e18
    uint256 waConvertThreshold;
    //
    // TODO : update implementation of threshold, as currently it simplfies 
    // by just comparing the free balance with the threshold
    uint256 freeWaBalance;
    uint256 ammWaDepositThreshold;
    //
    uint256 ammCtDepositThreshold;
    uint256 freeCtBalance;
}

library VaultConfigLibrary {
    function initialize(
        uint256 fee,
        uint256 waConvertThreshold,
        uint256 ammWaDepositThreshold,
        uint256 ammCtDepositThreshold
    ) internal pure returns (VaultConfig memory) {
        return
            VaultConfig({
                fee: fee,
                waConvertThreshold: waConvertThreshold,
                ammWaDepositThreshold: ammWaDepositThreshold,
                freeWaBalance: 0,
                freeCtBalance: 0,
                ammCtDepositThreshold: ammCtDepositThreshold
            });
    }

    function mustDepositWaAmm(
        VaultConfig memory self
    ) internal pure returns (bool) {
        return self.freeWaBalance > self.ammWaDepositThreshold;
    }

    function mustDepositCtAmm(
        VaultConfig memory self
    ) internal pure returns (bool) {
        return self.freeCtBalance > self.ammCtDepositThreshold;
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

    function calcWa(
        VaultConfig memory self,
        uint256 amount
    ) internal pure returns (uint256 locked, uint256 free) {
        locked = amount - (amount * self.waConvertThreshold) / 1e20;
        free = amount - locked;
    }
}
