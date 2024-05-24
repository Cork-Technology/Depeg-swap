// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IAssetFactory.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Asset.sol";

contract AssetFactory is IAssetFactory, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice limit too long when getting deployed assets
    error LimitTooLong(uint256 max, uint256 received);

    /// @notice emitted when a new CT + DS assets is deployed
    event AssetDeployed(address indexed ct, address indexed ds);

    uint8 public constant MAX_LIMIT = 10;

    struct Assets {
        address ct;
        address ds;
        address ra;
        address wa;
        address pa;
    }

    mapping(uint256 => Assets) deployedAssets;
    uint256 idx;

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
    )
        external
        view
        override
        returns (address[] memory ct, address[] memory ds)
    {
        if (limit > MAX_LIMIT) {
            revert LimitTooLong(MAX_LIMIT, limit);
        }

        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);

        if (end > idx) {
            end = idx;
        }

        ct = new address[](end - start);
        ds = new address[](end - start);

        for (uint256 i = start; i < end; i++) {
            Assets storage asset = deployedAssets[i];
            ct[i - start] = asset.ct;
            ds[i - start] = asset.ds;
        }
    }

    function deploy(
        address ra,
        address pa,
        address wa
    ) external override onlyOwner returns (address ct, address ds) {
        uint256 _idx = idx++;

        string memory pairname = string(
            abi.encodePacked(Asset(ra).name(), "-", Asset(pa).name())
        );

        ct = address(new Asset("CT", pairname, _msgSender()));
        ds = address(new Asset("DS", pairname, _msgSender()));

        deployedAssets[_idx] = Assets(ct, ds, ra, wa, pa);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner notDelegated {}
}
