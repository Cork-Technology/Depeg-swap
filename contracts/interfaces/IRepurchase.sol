pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";

/**
 * @title IRepurchase Interface
 * @author Cork Team
 * @notice IRepurchase interface for supporting Repurchase features through PSMCore
 */
interface IRepurchase {
    /**
     * @notice emitted when repurchase is done
     * @param id the id of PSM
     * @param buyer the address of the buyer
     * @param dsId the id of the DS
     * @param raUsed the amount of RA used
     * @param received the amount of RA used
     * @param fee the fee charged
     * @param feePercentage the fee in percentage
     * @param exchangeRates the effective DS exchange rate at the time of repurchase
     */
    event Repurchased(
        Id indexed id,
        address indexed buyer,
        uint256 indexed dsId,
        uint256 raUsed,
        uint256 received,
        uint256 feePercentage,
        uint256 fee,
        uint256 exchangeRates
    );

    /// @notice Emitted when a repurchaseFee is updated for a given PSM
    /// @param Id The PSM id
    /// @param repurchaseFeeRate The new repurchaseFee rate
    event RepurchaseFeeRateUpdated(Id indexed Id, uint256 indexed repurchaseFeeRate);

    /**
     * @notice thrown when the user tries to repurchase more than the available PA + DSliquidity
     * @param available the amount of available PA + DS
     * @param requested the amount of PA + DS user will receive
     */
    error InsufficientLiquidity(uint256 available, uint256 requested);

    /**
     * @notice returns the fee percentage for repurchasing(1e18 = 1%)
     * @param id the id of PSM
     */
    function repurchaseFee(Id id) external view returns (uint256);

    /**
     * @notice repurchase using RA
     * @param id the id of PSM
     * @param amount the amount of RA to use
     */
    function repurchase(Id id, uint256 amount)
        external
        returns (uint256 dsId, uint256 received, uint256 feePercentage, uint256 fee, uint256 exchangeRates);

    /**
     * @notice returns the amount of pa and ds tokens that will be received after repurchasing
     * @param id the id of PSM
     * @param amount the amount of RA to use
     * @return dsId the id of the DS
     * @return received the amount of RA received
     * @return feePercentage the fee in percentage
     * @return fee the fee charged
     * @return exchangeRates the effective DS exchange rate at the time of repurchase
     */
    function previewRepurchase(Id id, uint256 amount)
        external
        view
        returns (uint256 dsId, uint256 received, uint256 feePercentage, uint256 fee, uint256 exchangeRates);

    /**
     * @notice return the amount of available PA and DS to purchase.
     * @param id the id of PSM
     * @return pa the amount of PA available
     * @return ds the amount of DS available
     * @return dsId the id of the DS available
     */
    function availableForRepurchase(Id id) external view returns (uint256 pa, uint256 ds, uint256 dsId);

    /**
     * @notice returns the repurchase rates for a given DS
     * @param id the id of PSM
     */
    function repurchaseRates(Id id) external view returns (uint256 rates);
}
