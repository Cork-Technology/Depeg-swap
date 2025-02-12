// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface ILiquidatorRegistry {
    function isLiquidationWhitelisted(address liquidationAddress) external view returns (bool);

    function blacklist(address liquidationAddress) external;

    function whitelist(address liquidationAddress) external;
}
