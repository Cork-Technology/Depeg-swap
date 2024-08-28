pragma solidity 0.8.24;

import {IAssetFactory} from "../../interfaces/IAssetFactory.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";
import {Asset} from "./Asset.sol";

/**
 * @title Factory contract for Assets
 * @author Cork Team
 * @notice Factory contract for deploying assets contracts
 */
contract AssetFactory is IAssetFactory, OwnableUpgradeable, UUPSUpgradeable {
    using PairLibrary for Pair;

    uint8 public constant MAX_LIMIT = 10;
    string private constant CT_PREFIX = "CT";
    string private constant DS_PREFIX = "DS";
    string private constant LV_PREFIX = "LV";

    uint256 internal idx;

    mapping(Id => address) internal lvs;
    mapping(uint256 => Pair) internal pairs;
    mapping(Id => Pair[]) internal swapAssets;
    mapping(address => bool) internal deployed;

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

    /**
     * @notice initializes asset factory contract and setup owner
     * @param moduleCore the address of Module Core contract
     */
    function initialize(address moduleCore) external initializer notDelegated {
        __Ownable_init(moduleCore);
        __UUPSUpgradeable_init();
    }

    function getDeployedAssets(uint8 page, uint8 limit)
        external
        view
        override
        withinLimit(limit)
        returns (address[] memory ra, address[] memory lv)
    {
        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);
        uint256 arrLen = end - start;

        if (end > idx) {
            end = idx;
        }

        if (start > idx) {
            return (ra, lv);
        }

        ra = new address[](arrLen);
        lv = new address[](arrLen);

        for (uint256 i = start; i < end; i++) {
            Pair storage asset = pairs[i];
            uint8 _idx = uint8(i - start);

            ra[_idx] = asset.pair1;
            lv[_idx] = lvs[asset.toId()];
        }
    }

    function getDeployedSwapAssets(address ra, address pa, uint8 page, uint8 limit)
        external
        view
        override
        withinLimit(limit)
        returns (address[] memory ct, address[] memory ds)
    {
        Pair[] storage _assets = swapAssets[Pair(pa, ra).toId()];

        uint256 start = uint256(page) * uint256(limit);
        uint256 end = start + uint256(limit);
        uint256 arrLen = end - start;

        if (end > _assets.length) {
            end = _assets.length;
        }

        if (start > _assets.length) {
            return (ct, ds);
        }

        ct = new address[](arrLen);
        ds = new address[](arrLen);

        for (uint256 i = start; i < end; i++) {
            ct[i - start] = _assets[i].pair0;
            ds[i - start] = _assets[i].pair1;
        }
    }

    function deploySwapAssets(address ra, address pa, address owner, uint256 expiry, uint256 psmExchangeRate)
        external
        override
        onlyOwner
        notDelegated
        returns (address ct, address ds)
    {
        Pair memory asset = Pair(pa, ra);

        // prevent deploying a swap asset of a non existent pair, logically won't ever happen
        // just to be safe
        if (lvs[asset.toId()] == address(0)) {
            revert NotExist(ra, pa);
        }

        string memory pairname = string(abi.encodePacked(Asset(ra).name(), "-", Asset(pa).name()));

        ct = address(new Asset(CT_PREFIX, pairname, owner, expiry, psmExchangeRate));
        ds = address(new Asset(DS_PREFIX, pairname, owner, expiry, psmExchangeRate));

        swapAssets[Pair(pa, ra).toId()].push(Pair(ct, ds));

        deployed[ct] = true;
        deployed[ds] = true;

        emit AssetDeployed(ra, ct, ds);
    }

    function deployLv(address ra, address pa, address owner)
        external
        override
        onlyOwner
        notDelegated
        returns (address lv)
    {
        lv = address(
            new Asset(LV_PREFIX, string(abi.encodePacked(Asset(ra).name(), "-", Asset(pa).name())), owner, 0, 0)
        );

        // signal that a pair actually exists. Only after this it's possible to deploy a swap asset for this pair
        Pair memory pair = Pair(pa, ra);
        pairs[idx++] = pair;

        lvs[pair.toId()] = lv;

        emit LvAssetDeployed(ra, pa, lv);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner notDelegated {}
}
