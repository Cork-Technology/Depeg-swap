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

    address public moduleCore;
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

    /**
     *
     * @param baseSymbol The base symbol to which the variant number will be appended.
     * @param id The unique identifier used to determine the variant number.
     * @return variant The generated variant string.
     */
    function _generateVariant(string memory baseSymbol, Id id) internal returns (string memory variant) {
        bytes32 hash = keccak256(abi.encodePacked(baseSymbol));

        // this will assign a fixed variant number to a pair
        // so if the same pair deploys a new asset it will have the same variant number
        uint256 variantUint = variantIndexPair[id] == 0 ? ++variantIndex[hash] : variantIndexPair[id];
        variantIndexPair[id] = variantUint;

        variant = string.concat(baseSymbol, "-", Strings.toString(variantUint));
    }

    /**
     * @dev will generate symbol such as wstETH03CT-1.
     * @param pa The address of the ERC20 token.
     * @param expiry The expiry date in Unix timestamp format. If 0, a special separator is used.
     * @param prefix The prefix to be added to the symbol.
     * @param id The identifier used to generate the variant.
     * @return symbol The generated symbol with the variant.
     */
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

    modifier onlyModuleCore() {
        if (moduleCore != msg.sender) {
            revert NotModuleCore();
        }
        _;
    }

    /**
     * @notice Retrieves the address of the liquidity vault (LV) for a given pair and parameters.
     * @param _ra The address of the reserve asset.
     * @param _pa The address of the paired asset.
     * @param initialArp The initial annualized return percentage.
     * @param expiryInterval The expiry interval for the liquidity vault.
     * @param exchangeRateProvider The address of the exchange rate provider.
     * @return The address of the liquidity vault corresponding to the given parameters.
     */
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

    /**
     * @notice Deploys new swap assets based on the provided parameters.
     * @dev This function deploys two new Asset contracts and registers them as a swap pair.
     * @param params The parameters required to deploy the swap assets.
     * @return ct The address of the first deployed Asset contract.
     * @return ds The address of the second deployed Asset contract.
     */
    function deploySwapAssets(DeployParams calldata params)
        external
        override
        onlyModuleCore
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
    ) external override onlyModuleCore returns (address lv) {
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

    /**
     * @notice Sets the address of the module core.
     * @dev This function can only be called by the owner of the contract.
     *      It reverts if the provided address is the zero address.
     * @param _moduleCore The address of the new module core.
     */
    function setModuleCore(address _moduleCore) external onlyOwner {
        if (_moduleCore == address(0)) {
            revert ZeroAddress();
        }
        moduleCore = _moduleCore;
        emit ModuleCoreChanged(moduleCore, _moduleCore);
    }
}
