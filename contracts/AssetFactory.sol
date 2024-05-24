// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IAssetFactory.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./WrappedAsset.sol";
import "./Asset.sol";

// IAssetFactory
contract AssetFactory is OwnableUpgradeable, UUPSUpgradeable {
    /// @notice limit too long when getting deployed assets
    error LimitTooLong(uint256 max, uint256 received);

    /// @notice emitted when a new CT + DS assets is deployed
    event AssetDeployed(address indexed ct, address indexed ds);

    /// @notice emitted when a new WrappedAsset is deployed
    event WrappedAssetDeployed(address indexed wa, address indexed ra);

    uint8 public constant MAX_LIMIT = 10;

    struct WrappedAssets {
        address ra;
        address wa;
        address pa;
    }

    struct SwapAssets {
        address ct;
        address ds;
    }

    uint256 idx;
    mapping(uint256 => WrappedAssets) wrappedAssets;
    mapping(address => SwapAssets[]) swapAssets;

    modifier withinLimit(uint8 limit) {
        if (limit > MAX_LIMIT) {
            revert LimitTooLong(MAX_LIMIT, limit);
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer notDelegated {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function getDeployedWrappedAssets(
        uint8 page,
        uint8 limit
    )
        external
        view
        withinLimit(limit)
        returns (address[] memory ra, address[] memory pa, address[] memory wa)
    {
        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);

        if (end > idx) {
            end = idx;
        }

        ra = new address[](end - start);
        pa = new address[](end - start);
        wa = new address[](end - start);

        for (uint256 i = start; i < end; i++) {
            WrappedAssets storage asset = wrappedAssets[i];
            ra[i - start] = asset.ra;
            pa[i - start] = asset.pa;
            wa[i - start] = asset.wa;
        }
    }

    function getDeployedSwapAssets(
        address wa,
        uint8 page,
        uint8 limit
    )
        external
        view
        withinLimit(limit)
        returns (address[] memory ct, address[] memory ds)
    {
        SwapAssets[] storage assets = swapAssets[wa];

        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);

        if (end > assets.length) {
            end = assets.length;
        }

        ct = new address[](end - start);
        ds = new address[](end - start);

        for (uint256 i = start; i < end; i++) {
            ct[i - start] = assets[i].ct;
            ds[i - start] = assets[i].ds;
        }
    }

    function deploySwapAssets(
        address ra,
        address pa,
        address wa,
        uint256 expiry
    ) external onlyOwner notDelegated returns (address ct, address ds) {
        string memory pairname = string(
            abi.encodePacked(Asset(ra).name(), "-", Asset(pa).name())
        );

        ct = address(new Asset("CT", pairname, _msgSender(), expiry));
        ds = address(new Asset("DS", pairname, _msgSender(), expiry));

        swapAssets[wa].push(SwapAssets(ct, ds));
    }

    function deployWrappedAsset(
        address ra,
        address pa
    ) external onlyOwner notDelegated returns (address wa) {
        uint256 _idx = idx++;

        wa = address(new WrappedAsset(ra));

        wrappedAssets[_idx] = WrappedAssets(ra, wa, pa);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner notDelegated {}
}
