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
    mapping(address => bool) internal deployed;
    mapping(bytes32 => uint256) internal variantIndex;
    mapping(Id => uint256) internal variantIndexPair;

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    constructor() {
        _disableInitializers();
    }

    function _generateVariant(string memory baseSymbol, Id id) internal returns (string memory variant) {
        bytes32 hash = keccak256(abi.encodePacked(baseSymbol));

        // this will assign a fixed variant number to a pair
        // so if the same pair deploys a new asset it will have the same variant number
        uint256 variantUint = variantIndexPair[id] == 0 ? ++variantIndex[hash] : variantIndexPair[id];
        variantIndexPair[id] = variantUint;

        variant = string.concat(baseSymbol, "-", Strings.toString(variantUint));
    }

    // will generate symbol such as wstETH03CT-1
    function _generateSymbolWithVariant(address pa, uint256 expiry, string memory prefix, Id id)
        internal
        returns (string memory symbol)
    {
        string memory baseSymbol = IERC20Metadata(pa).symbol();
        string memory separator = expiry == 0 ? "!" : Strings.toString(BokkyPooBahsDateTimeLibrary.getMonth(expiry));

        string memory base = string.concat(baseSymbol, separator, prefix);

        symbol = _generateVariant(base, id);
    }

    /**
     * @notice for safety checks in psm core, also act as kind of like a registry
     * @param asset the address of Asset contract
     */
    function isDeployed(address asset) external view override returns (bool) {
        return deployed[asset];
    }

    modifier withinLimit(uint8 _limit) {
        if (_limit > MAX_LIMIT) {
            revert LimitTooLong(MAX_LIMIT, _limit);
        }
        _;
    }

    function getLv(address _ra, address _pa, uint256 initialArp, uint256 expiryInterval, address exchangeRateProvider)
        external
        view
        override
        returns (address)
    {
        return lvs[Pair(_pa, _ra, initialArp, expiryInterval, exchangeRateProvider).toId()];
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
    function getDeployedSwapAssets(
        address _ra,
        address _pa,
        uint256 _initialArp,
        uint256 _expiryInterval,
        address _exchangeRateProvider,
        uint8 _page,
        uint8 _limit
    ) external view override withinLimit(_limit) returns (address[] memory ct, address[] memory ds) {
        SwapPair[] storage _assets =
            swapAssets[Pair(_pa, _ra, _initialArp, _expiryInterval, _exchangeRateProvider).toId()];

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

    function deploySwapAssets(DeployParams calldata params)
        external
        override
        onlyOwner
        returns (address ct, address ds)
    {
        if (params.psmExchangeRate == 0) {
            revert InvalidRate();
        }
        Pair memory asset =
            Pair(params._pa, params._ra, params.initialArp, params.expiryInterval, params.exchangeRateProvider);
        Id id = asset.toId();

        uint256 expiry = block.timestamp + params.expiryInterval;

        // prevent deploying a swap asset of a non existent pair, logically won't ever happen
        // just to be safe
        if (lvs[id] == address(0)) {
            revert NotExist(params._ra, params._pa);
        }

        {
            ct = address(
                new Asset(
                    _generateSymbolWithVariant(asset.pa, expiry, CT_PREFIX, id),
                    params._owner,
                    expiry,
                    params.psmExchangeRate,
                    params.dsId
                )
            );
            ds = address(
                new Asset(
                    _generateSymbolWithVariant(asset.pa, expiry, DS_PREFIX, id),
                    params._owner,
                    expiry,
                    params.psmExchangeRate,
                    params.dsId
                )
            );
        }

        swapAssets[id].push(SwapPair(ct, ds));

        deployed[ct] = true;
        deployed[ds] = true;

        emit AssetDeployed(params._ra, ct, ds);
    }

    /**
     * @notice deploys new LV Assets for given RA & PA
     * @param _ra Address of RA
     * @param _pa Address of PA
     * @param _owner Address of asset owners
     * @return lv new LV contract address
     */
    function deployLv(
        address _ra,
        address _pa,
        address _owner,
        uint256 _initialArp,
        uint256 _expiryInterval,
        address _exchangeRateProvider
    ) external override onlyOwner returns (address lv) {
        // signal that a pair actually exists. Only after this it's possible to deploy a swap asset for this pair
        Pair memory pair = Pair(_pa, _ra, _initialArp, _expiryInterval, _exchangeRateProvider);

        {
            string memory pairname = _generateSymbolWithVariant(_pa, 0, LV_PREFIX, pair.toId());
            lv = address(new Asset(pairname, _owner, 0, 0, 0));
        }

        // solhint-disable-next-line gas-increment-by-one
        pairs[idx++] = pair;

        lvs[pair.toId()] = lv;

        emit LvAssetDeployed(_ra, _pa, lv);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
