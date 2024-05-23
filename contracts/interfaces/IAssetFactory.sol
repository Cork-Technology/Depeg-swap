// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAssetFactory {
    function getDeployedAssets(
        uint8 page,
        uint8 limit
    ) external view returns (address[] memory);

    function deploy(
        address ra,
        address pa
    ) external returns (address ct, address ds);
}
