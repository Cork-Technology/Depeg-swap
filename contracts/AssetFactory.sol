// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IAssetFactory.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Asset.sol";

contract AssetFactory is IAssetFactory, OwnableUpgradeable, UUPSUpgradeable {
    address[] public deployedAssets;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer notDelegated {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function getDeployedAssets(
        uint8 page,
        uint8 limit
    ) external view override returns (address[] memory) {
        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);
        if (end > deployedAssets.length) {
            end = deployedAssets.length;
        }
        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = deployedAssets[i];
        }
        return result;
    }

    function deploy(
        address ra,
        address pa
    ) external override onlyOwner returns (address ct, address ds) {
        string memory pairname = string(
            abi.encodePacked(Asset(ra).name(), "-", Asset(pa).name())
        );

        ct = address(new Asset("CT", pairname, _msgSender()));
        ds = address(new Asset("DS", pairname, _msgSender()));

        deployedAssets.push(address(ct));
        return (address(ct), address(ds));
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner notDelegated {}
}
