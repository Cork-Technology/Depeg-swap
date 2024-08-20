// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {VaultConfig} from "./State.sol";

library VaultConfigLibrary {
    function initialize(uint256 fee, uint256 ammWaDepositThreshold, uint256 ammCtDepositThreshold)
        internal
        pure
        returns (VaultConfig memory)
    {
        return VaultConfig({
            fee: fee,
            ammRaDepositThreshold: ammWaDepositThreshold,
            lpRaBalance: 0,
            lpCtBalance: 0,
            ammCtDepositThreshold: ammCtDepositThreshold,
            lpBalance: 0,
            isDepositPaused: false,
            isWithdrawalPaused: false
        });
    }

    function mustProvideLiquidity(VaultConfig memory self) internal pure returns (bool) {
        return (self.lpRaBalance > self.ammRaDepositThreshold) && (self.lpCtBalance > self.ammCtDepositThreshold);
    }

    function updateFee(VaultConfig storage self, uint256 fee) internal {
        self.fee = fee;
    }

    function updateAmmDepositThreshold(VaultConfig storage self, uint256 ammDepositThreshold) internal {
        self.ammRaDepositThreshold = ammDepositThreshold;
    }
}
