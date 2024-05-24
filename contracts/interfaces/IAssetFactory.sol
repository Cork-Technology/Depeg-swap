// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAssetFactory {
    function getDeployedWrappedAssets(
        uint8 page,
        uint8 limit
    )
        external
        view
        returns (address[] memory ra, address[] memory pa, address[] memory wa);

    function getDeployedSwapAssets(
        address wa,
        uint8 page,
        uint8 limit
    ) external view returns (address[] memory ct, address[] memory ds);

    function deploySwapAssets(
        address ra,
        address pa,
        address wa,
        uint256 expiry
    ) external returns (address ct, address ds);

    function deployWrappedAsset(
        address ra,
        address pa
    ) external returns (address wa);
}
