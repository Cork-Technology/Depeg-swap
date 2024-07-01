// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./State.sol";

library VaultPoolLibrary {
    function initialize() internal pure returns (VaultPool memory) {
        return
            VaultPool(
                VaultWithdrawalPool(0, 0, 0, 0, 0, 0),
                VaultAmmLiquidityPool(0)
            );
    }

    function reserve(
        VaultPool storage self,
        uint256 addedLv,
        uint256 addedRa,
        uint256 addedPa
    ) internal {}

    function redeemfromWithdrawalPool(
        VaultPool storage self,
        uint256 amount
    ) internal {}

    function redeemFromAmmPool(
        VaultPool storage self,
        uint256 amount
    ) internal {}
}
