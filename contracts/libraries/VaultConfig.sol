// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// TODO : remove all threshold

struct VaultConfig {
    // 1 % = 1e18
    uint256 fee;
    //
    uint256 lpWaBalance;
    uint256 ammWaDepositThreshold;
    //
    uint256 ammCtDepositThreshold;
    uint256 lpCtBalance;

    uint256 accmulatedFee;
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
                lpWaBalance: 0,
                lpCtBalance: 0,
                ammCtDepositThreshold: ammCtDepositThreshold,
                accmulatedFee: 0
            });
    }

    function mustProvideLiquidity(
        VaultConfig memory self
    ) internal pure returns (bool) {
        return
            (self.lpWaBalance > self.ammWaDepositThreshold) &&
            (self.lpCtBalance > self.ammCtDepositThreshold);
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

}
