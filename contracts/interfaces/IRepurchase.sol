// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/Pair.sol";

interface IRepurchase {
    /**
     * @notice emitted when repurchase is done
     * @param id the id of PSM
     * @param buyer the address of the buyer
     * @param dsId the id of the DS
     * @param raUsed the amount of RA used
     * @param received the amount of RA used
     * @param fee the fee charged
     * @param feePrecentage the fee in precentage
     */
    event Repurchased(
        Id indexed id,
        address indexed buyer,
        uint256 dsId,
        uint256 raUsed,
        uint256 received,
        uint256 feePrecentage,
        uint256 fee
    );

    /**
     * @notice returns the fee precentage for repurchasing(1e18 = 1%)
     * @param id the id of PSM
     */
    function repurchaseFee(Id id) external view returns (uint256);

    /**
     * @notice repurchase using RA
     * @param id the id of PSM
     * @param amount the amount of RA to use
     */
    function repurchase(Id id, uint256 amount) external;

    /**
     * @notice returns the amount of pa and ds tokens that will be received after repurchasing
     * @param id the id of PSM
     * @param amount the amount of RA to use
     * @return pa the amount of PA received
     * @return ds the amount of DS received
     */
    function previewRepurchase(
        Id id,
        uint256 amount
    ) external view returns (uint256 pa, uint256 ds, uint256 dsId);

    /**
     * @notice return the amount of available PA and DS to purchase.
     * @param id the id of PSM
     * @return pa the amount of PA available
     * @return ds the amount of DS available
     * @return dsId the id of the DS available
     */
    function availableForRepurchase(
        Id id
    ) external view returns (uint256 pa, uint256 ds, uint256 dsId);

    /**
     * @notice returns the repurchase rates for a given DS
     * @param id the id of PSM
     */
    function repurchaseRates(Id id) external view returns (uint256 rates);
}
