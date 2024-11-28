pragma solidity 0.8.26;

interface ILiquidatorRegistry {
    function isLiquidationWhitelisted(address liquidationAddress) external view returns (bool);

    function blacklist(address liquidationAddress) external;

    function whitelist(address liquidationAddress) external;
}
