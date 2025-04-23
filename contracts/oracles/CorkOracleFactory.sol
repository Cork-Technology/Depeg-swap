// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ICorkOracleFactory, CorkOracleType, PriceFeedParams} from "../interfaces/ICorkOracleFactory.sol";
import {Initialize} from "../interfaces/Init.sol";
import {CompositePriceFeed} from "./CompositePriceFeed.sol";
import {LinearDiscountOracle} from "./LinearDiscountOracle.sol";
import {Id} from "../libraries/Pair.sol";

struct OracleMetadata {
    CorkOracleType oracleType;
}

/**
 * @title Factory contract for Cork Oracles
 * @author Cork Team
 * @custom:contact security@cork.tech
 * @notice This contract allows to create Cork oracles, and to index them easily.
 */
contract CorkOracleFactory is OwnableUpgradeable, UUPSUpgradeable, ICorkOracleFactory {
    /* STORAGE */

    Initialize public moduleCore;
    mapping(address => OracleMetadata) public oracles;

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the factory contract
     * @param _owner The owner of the factory contract
     */
    function initialize(address _owner, address _moduleCore) external initializer {
        if (_owner == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        moduleCore = Initialize(_moduleCore);
    }

    /* EXTERNAL */

    /// @notice Whether an oracle was created with the factory.
    /// @inheritdoc ICorkOracleFactory
    function isCorkOracle(address target) external view returns (bool) {
        return oracles[target].oracleType != CorkOracleType.NONE;
    }

    /// @notice Whether a feed (push-based oracle) was created with the factory.
    /// @inheritdoc ICorkOracleFactory
    function isCorkPriceFeed(address target) external view returns (bool) {
        return oracles[target].oracleType == CorkOracleType.PRICE_FEED;
    }

    /// @inheritdoc ICorkOracleFactory
    function createCompositePriceFeed(PriceFeedParams[] calldata params, bytes32 salt)
        external
        returns (CompositePriceFeed oracle)
    {
        oracle = new CompositePriceFeed{salt: salt}(params);
        oracles[address(oracle)] = OracleMetadata(CorkOracleType.PRICE_FEED);
        emit CreateCompositePriceFeedV1(msg.sender, address(oracle));
    }

    function createLinearDiscountOracle(address ct, uint256 baseDiscountPerYear)
        external
        returns (LinearDiscountOracle oracle)
    {
        oracle = new LinearDiscountOracle(ct, baseDiscountPerYear);
        oracles[address(oracle)] = OracleMetadata(CorkOracleType.LINEAR_DISCOUNT);
        emit CreateLinearDiscountOracleV1(msg.sender, address(oracle));
    }

    function createLinearDiscountOracleWithMarket(Id marketId, uint256 epoch, uint256 baseDiscountPerYear)
        external
        returns (LinearDiscountOracle oracle)
    {
        (address ct,) = moduleCore.swapAsset(marketId, epoch);
        oracle = new LinearDiscountOracle(ct, baseDiscountPerYear);
        oracles[address(oracle)] = OracleMetadata(CorkOracleType.LINEAR_DISCOUNT);
        emit CreateLinearDiscountOracleV1(msg.sender, address(oracle));
    }

    /// @notice Authorization function for UUPS proxy upgrades
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
