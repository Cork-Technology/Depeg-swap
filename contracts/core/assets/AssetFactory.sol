// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IAssetFactory} from "../../interfaces/IAssetFactory.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Id, Pair, PairLibrary} from "../../libraries/Pair.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Asset} from "./Asset.sol";
import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/BokkyPooBahsDateTimeLibrary.sol";

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

    struct SwapPair {
        address ct;
        address ds;
    }

    mapping(Id => address) internal lvs;
    mapping(uint256 => Pair) internal pairs;
    mapping(Id => SwapPair[]) internal swapAssets;
    mapping(address => uint256) internal deployed;

    /// @notice __gap variable to prevent storage collisions
    uint256[49] __gap;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice for safety checks in psm core, also act as kind of like a registry
     * @param asset the address of Asset contract
     */
    function isDeployed(address asset) external view override returns (bool) {
        return (deployed[asset] == 1 ? true : false);
    }

    modifier withinLimit(uint8 _limit) {
        if (_limit > MAX_LIMIT) {
            revert LimitTooLong(MAX_LIMIT, _limit);
        }
        _;
    }

    function getLv(address _ra, address _pa, uint256 expiryInterval) external view override returns (address) {
        return lvs[Pair(_pa, _ra, expiryInterval).toId()];
    }

    /**
     * @notice initializes asset factory contract and setup owner
     */
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice for getting list of deployed Assets with this factory
     * @param _page page number
     * @param _limit number of entries per page
     * @return ra list of deployed RA assets
     * @return lv list of deployed LV assets
     */
    function getDeployedAssets(uint8 _page, uint8 _limit)
        external
        view
        override
        withinLimit(_limit)
        returns (address[] memory ra, address[] memory lv)
    {
        uint256 start = uint256(_page) * uint256(_limit);
        uint256 end = start + uint256(_limit);

        if (end > idx) {
            end = idx;
        }

        if (start > idx) {
            return (ra, lv);
        }

        uint256 arrLen = end - start;
        ra = new address[](arrLen);
        lv = new address[](arrLen);

        for (uint256 i = start; i < end; ++i) {
            Pair storage asset = pairs[i];
            uint8 _idx = uint8(i - start);

            ra[_idx] = asset.ra;
            lv[_idx] = lvs[asset.toId()];
        }
    }

    /**
     * @notice for getting list of deployed SwapAssets with this factory
     * @param _ra Address of RA
     * @param _pa Address of PA
     * @param _page page number
     * @param _limit number of entries per page
     * @return ct list of deployed CT assets
     * @return ds list of deployed DS assets
     */
    function getDeployedSwapAssets(address _ra, address _pa, uint256 _expiryInterval, uint8 _page, uint8 _limit)
        external
        view
        override
        withinLimit(_limit)
        returns (address[] memory ct, address[] memory ds)
    {
        SwapPair[] storage _assets = swapAssets[Pair(_pa, _ra, _expiryInterval).toId()];

        uint256 start = uint256(_page) * uint256(_limit);
        uint256 end = start + uint256(_limit);

        if (end > _assets.length) {
            end = _assets.length;
        }

        if (start > _assets.length) {
            return (ct, ds);
        }

        uint256 arrLen = end - start;
        ct = new address[](arrLen);
        ds = new address[](arrLen);

        for (uint256 i = start; i < end; ++i) {
            ct[i - start] = _assets[i].ct;
            ds[i - start] = _assets[i].ds;
        }
    }

    /**
     * @notice deploys new Swap Assets for given RA & PA
     * @param _ra Address of RA
     * @param _pa Address of PA
     * @param _owner Address of asset owners
     * @param expiryInterval expiry interval in seconds
     * @param psmExchangeRate exchange rate for this pair
     * @return ct new CT contract address
     * @return ds new DS contract address
     */
    function deploySwapAssets(
        address _ra,
        address _pa,
        address _owner,
        uint256 expiryInterval,
        uint256 psmExchangeRate,
        uint256 dsId
    ) external override onlyOwner returns (address ct, address ds) {
        Pair memory asset = Pair(_pa, _ra, expiryInterval);

        uint256 expiry = block.timestamp + expiryInterval;

        string memory pairname;

        {
            (uint256 year, uint256 month, uint256 day) = BokkyPooBahsDateTimeLibrary.timestampToDate(expiry);
            string memory expiryAsStrings =
                string.concat(Strings.toString(year), "-", Strings.toString(month), "-", Strings.toString(day));

            pairname =
                string.concat(IERC20Metadata(_ra).symbol(), "-", IERC20Metadata(_pa).symbol(), "-", expiryAsStrings);
        }

        // prevent deploying a swap asset of a non existent pair, logically won't ever happen
        // just to be safe
        if (lvs[asset.toId()] == address(0)) {
            revert NotExist(_ra, _pa);
        }

        ct = address(new Asset(CT_PREFIX, pairname, _owner, expiry, psmExchangeRate, dsId));
        ds = address(new Asset(DS_PREFIX, pairname, _owner, expiry, psmExchangeRate, dsId));

        swapAssets[Pair(_pa, _ra, expiryInterval).toId()].push(SwapPair(ct, ds));

        deployed[ct] = 1;
        deployed[ds] = 1;

        emit AssetDeployed(_ra, ct, ds);
    }

    /**
     * @notice deploys new LV Assets for given RA & PA
     * @param _ra Address of RA
     * @param _pa Address of PA
     * @param _owner Address of asset owners
     * @return lv new LV contract address
     */
    function deployLv(address _ra, address _pa, address _owner, uint256 _expiryInterval)
        external
        override
        onlyOwner
        returns (address lv)
    {
        string memory pairname;

        {
            pairname = string.concat(IERC20Metadata(_ra).symbol(), "-", IERC20Metadata(_pa).symbol());
        }

        lv = address(new Asset(LV_PREFIX, pairname, _owner, 0, 0, 0));

        // signal that a pair actually exists. Only after this it's possible to deploy a swap asset for this pair
        Pair memory pair = Pair(_pa, _ra, _expiryInterval);
        pairs[idx++] = pair;

        lvs[pair.toId()] = lv;

        emit LvAssetDeployed(_ra, _pa, lv);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
