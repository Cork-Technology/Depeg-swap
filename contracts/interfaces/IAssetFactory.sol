// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAssetFactory {
    function getDeployedAssets(
        uint8 page,
        uint8 limit
    ) external view returns (address[] memory ct, address[] memory ds);

    function deploy(
        address ra,
        address pa,
        address wa
    ) external returns (address ct, address ds);
}
