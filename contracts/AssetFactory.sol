// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IAssetFactory.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./WrappedAsset.sol";
import "./libraries/Pair.sol";
import "./Asset.sol";

// TODO : add LV asset
contract AssetFactory is IAssetFactory, OwnableUpgradeable, UUPSUpgradeable {
    using PairLibrary for Pair;

    uint8 public constant MAX_LIMIT = 10;
    string private constant CT_PREFIX = "CT";
    string private constant DS_PREFIX = "DS";
    string private constant LV_PREFIX = "LV";

    uint256 idx;

    mapping(Id => address) lvs;
    mapping(uint256 => Pair) wrappedAssets;
    mapping(address => Pair[]) swapAssets;
    mapping(address => bool) deployed;

    // for safety checks in psm core, also act as kind of like a registry
    function isDeployed(address asset) external view override returns (bool) {
        return deployed[asset];
    }

    modifier withinLimit(uint8 limit) {
        if (limit > MAX_LIMIT) {
            revert LimitTooLong(MAX_LIMIT, limit);
        }
        _;
    }

    constructor() {}

    function initialize() external initializer notDelegated {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function getDeployedWrappedAssets(
        uint8 page,
        uint8 limit
    )
        external
        view
        override
        withinLimit(limit)
        returns (address[] memory ra, address[] memory wa, address[] memory lv)
    {
        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);
        uint256 arrLen = end - start;

        if (end > idx) {
            end = idx;
        }

        if (start > idx) {
            return (ra, wa, lv);
        }

        ra = new address[](arrLen);
        wa = new address[](arrLen);

        for (uint256 i = start; i < end; i++) {
            Pair storage asset = wrappedAssets[i];
            uint8 _idx = uint8(i - start);

            ra[_idx] = asset.pair0;
            wa[_idx] = asset.pair1;
            lv[_idx] = lvs[asset.toId()];
        }
    }

    function getDeployedSwapAssets(
        address wa,
        uint8 page,
        uint8 limit
    )
        external
        view
        override
        withinLimit(limit)
        returns (address[] memory ct, address[] memory ds)
    {
        Pair[] storage assets = swapAssets[wa];

        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);
        uint256 arrLen = end - start;

        if (end > assets.length) {
            end = assets.length;
        }

        ct = new address[](arrLen);
        ds = new address[](arrLen);

        for (uint256 i = start; i < end; i++) {
            ct[i - start] = assets[i].pair0;
            ds[i - start] = assets[i].pair1;
        }
    }

    function deploySwapAssets(
        address ra,
        address pa,
        address wa,
        address owner,
        uint256 expiry
    )
        external
        override
        onlyOwner
        notDelegated
        returns (address ct, address ds)
    {
        string memory pairname = string(
            abi.encodePacked(Asset(ra).name(), "-", Asset(pa).name())
        );

        ct = address(new Asset(CT_PREFIX, pairname, owner, expiry));
        ds = address(new Asset(DS_PREFIX, pairname, owner, expiry));

        // TODO : tests this with ~100 pairs
        swapAssets[wa].push(Pair(ct, ds));

        deployed[ct] = true;
        deployed[ds] = true;

        emit AssetDeployed(wa, ct, ds);
    }

    function deployLv(
        address ra,
        address pa,
        address wa,
        address owner
    ) external onlyOwner notDelegated returns (address lv) {
        lv = address(
            new Asset(
                LV_PREFIX,
                string(
                    abi.encodePacked(Asset(ra).name(), "-", Asset(pa).name())
                ),
                owner,
                0
            )
        );
        Pair memory pair = Pair(ra, wa);
        lvs[pair.toId()] = lv;

        emit LvAssetDeployed(ra, pa, lv);
    }

    // TODO : owner will be config contract later
    function deployWrappedAsset(
        address ra
    ) external override onlyOwner notDelegated returns (address wa) {
        uint256 _idx = idx++;

        wa = address(new WrappedAsset(ra));

        wrappedAssets[_idx] = Pair(ra, wa);

        deployed[wa] = true;

        emit WrappedAssetDeployed(ra, wa);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner notDelegated {}
}
