// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IErrors} from "./IErrors.sol";

/**
 * @title IDsFlashSwapUtility Interface
 * @author Cork Team
 * @notice Utility Interface for flashswap
 */
interface IDsFlashSwapUtility is IErrors {
    /**
     * @notice returns the current price ratio of the pair
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return raPriceRatio ratio of RA
     * @return ctPriceRatio ratio of CT
     */
    function getCurrentPriceRatio(Id id, uint256 dsId)
        external
        view
        returns (uint256 raPriceRatio, uint256 ctPriceRatio);

    /**
     * @notice Gets the AMM reserve for a specific reserve and DS.
     * @param id The id of the given pair in modulecore.
     * @param dsId The dsId of the pair in moduelcore.
     * @return raReserve The RA reserve amount.
     * @return ctReserve The CT reserve amount.
     */
    function getAmmReserve(Id id, uint256 dsId) external view returns (uint256 raReserve, uint256 ctReserve);

    /**
     * @notice returns the current DS reserve that is owned by liquidity vault
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return lvReserve the LV reserve amount
     */
    function getLvReserve(Id id, uint256 dsId) external view returns (uint256 lvReserve);

    /**
     * @notice returns the current DS reserve that is owned by PSM
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return psmReserve the PSM reserve amount
     */
    function getPsmReserve(Id id, uint256 dsId) external view returns (uint256 psmReserve);

    /**
     * @notice returns the current cumulative HIYA of the pair
     * @param id the id of the pair
     * @return hpaCummulative the current cumulative HIYA
     */
    function getCurrentCumulativeHIYA(Id id) external view returns (uint256 hpaCummulative);

    /**
     * @notice returns the current effective HIYA of the pair
     * @param id the id of the pair
     */
    function getCurrentEffectiveHIYA(Id id) external view returns (uint256 hpa);
}

/**
 * @title IDsFlashSwapCore Interface
 * @author Cork Team
 * @notice IDsFlashSwapCore interface for Flashswap Router contract
 */
interface IDsFlashSwapCore is IDsFlashSwapUtility {
    struct BuyAprroxParams {
        /// @dev the maximum amount of iterations to find the optimal amount of DS to swap, 256 is a good number
        uint256 maxApproxIter;
        /// @dev the maximum amount of iterations to find the optimal RA borrow amount(needed because of the fee, if any)
        uint256 maxFeeIter;
        /// @dev the amount that will be used to subtract borrowed amount to find the optimal amount for borrowing RA
        /// the lower the value, the more accurate the approximation will be but will be more expensive
        /// when in doubt use 0.01 ether or 1e16
        uint256 feeIntervalAdjustment;
        /// @dev the threshold tolerance that's used to find the optimal DS amount
        /// when in doubt use 1e9
        uint256 epsilon;
        /// @dev the threshold tolerance that's used to find the optimal RA amount to borrow, the smaller, the more accurate but more gas intensive it will be
        uint256 feeEpsilon;
        /// @dev the percentage buffer that's used to find the optimal DS amount. needed due to the inherent nature
        /// of the math that has some imprecision, this will be used to subtract the original amount, to offset the precision
        /// when in doubt use 0.01%(1e16) if you're trading above 0.0001 RA. Below that use 1-10%(1e17-1e18)
        uint256 precisionBufferPercentage;
    }

    /// @notice offchain guess for RA AMM borrowing used in swapping RA for DS.
    /// if empty, the router will try and calculate the optimal amount of RA to borrow
    /// using this will greatly reduce the gas cost.
    /// will be the default way to swap RA for DS
    struct OffchainGuess {
        uint256 borrowOnBuy;
        uint256 borrowOnFill;
    }

    struct SwapRaForDsReturn {
        uint256 amountOut;
        uint256 ctRefunded;
        /// @dev the amount of RA that needs to be borrowed on first iteration, this amount + user supplied / 2 of DS
        /// will be sold from the reserve unless it doesn't met the minimum amount, the DS reserve is empty,
        /// or the DS reserve sale is disabled. in such cases, this will be the final amount of RA that's borrowed
        /// and the "afterSoldBorrow" will be 0.
        /// if the swap is fully fullfilled by the rollover sale, borrow
        uint256 borrowOnBuy;
        uint256 borrowOnFill;
        uint256 fee;
        uint256 reserveSellPressure;
    }

    /**
     * @notice Emitted when DS is swapped for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param user the user that's swapping
     * @param amountIn the amount of DS that's swapped
     * @param amountOut the amount of RA that's received
     */
    event DsSwapped(
        Id indexed reserveId, uint256 indexed dsId, address indexed user, uint256 amountIn, uint256 amountOut
    );

    /**
     * @notice Emitted when RA is swapped for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param user the user that's swapping
     * @param amountIn  the amount of RA that's swapped
     * @param amountOut the amount of DS that's received
     * @param ctRefunded the amount of excess CT that's refunded to the user
     * @param fee the DS fee that's been cut from the user RA. derived from amountIn * feePercentage * reserveSellPercentage
     * @param feePercentage the fee percentage that's taken from user RA that's in theory filled with the reserve DS
     * @param reserveSellPercentage this is the percentage of the amount of DS that's been sold from the router
     */
    event RaSwapped(
        Id indexed reserveId,
        uint256 indexed dsId,
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        uint256 ctRefunded,
        uint256 fee,
        uint256 feePercentage,
        uint256 reserveSellPercentage
    );

    /**
     * @notice Emitted when a new issuance is made
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param ds the new DS address
     * @param pair the RA:CT pair id
     */
    event NewIssuance(Id indexed reserveId, uint256 indexed dsId, address ds, bytes32 pair);

    /**
     * @notice Emitted when a reserve is added
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS that's added to the reserve
     */
    event ReserveAdded(Id indexed reserveId, uint256 indexed dsId, uint256 amount);

    /**
     * @notice Emitted when a reserve is emptied
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS that's emptied from the reserve
     */
    event ReserveEmptied(Id indexed reserveId, uint256 indexed dsId, uint256 amount);

    /**
     * @notice Emitted when some DS is filled from the psm or vault reserve(or both)
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param user the user that's swapping
     * @param dsReceived the amount of DS that's received
     * @param raFilled the amount of RA that's filled
     */
    event Filled(
        Id indexed reserveId, uint256 indexed dsId, address indexed user, uint256 dsReceived, uint256 raFilled
    );

    /**
     * @notice trigger new issuance logic for a specific pair
     * @dev can only be called by the moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @param ds the address of the new issued DS
     * @param ra the address of RA token
     * @param ct the address of CT token
     */
    function onNewIssuance(Id reserveId, uint256 dsId, address ds, address ra, address ct) external;

    /**
     * @notice set the discount rate rate and rollover for the new issuance
     * @dev needed to avoid stack to deep errors. MUST be called after onNewIssuance and only by moduleCore at new issuance
     * @param reserveId the pair id
     * @param decayDiscountRateInDays the decay discount rate in days
     * @param rolloverPeriodInblocks the rollover period in blocks
     */
    function setDecayDiscountAndRolloverPeriodOnNewIssuance(
        Id reserveId,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) external;

    /**
     * @notice Updates the DS extra fee percentage for a specific reserve identified by `id`.
     * @dev This function can only be called by the config contract.
     * @param id The identifier of the reserve to update.
     * @param newPercentage The new DS extra fee percentage to be applied.
     */
    function updateDsExtraFeePercentage(Id id, uint256 newPercentage) external;

    /**
     * @notice Updates the DS extra fee treasury split percentage for a specific reserve identified by `id`.
     * @dev This function can only be called by the config contract.
     * @param id The identifier of the reserve to update.
     * @param newPercentage The new DS extra fee treasury split percentage to be applied.
     */
    function updateDsExtraFeeTreasurySplitPercentage(Id id, uint256 newPercentage) external;

    /**
     * @notice add more DS reserve from liquidity vault,
     * @dev can only be called by moduleCore
     * @param id the pair id
     * @param dsId the ds id of the pair
     * @param amount the amount of DS to add to the LV reserve
     */
    function addReserveLv(Id id, uint256 dsId, uint256 amount) external;

    /**
     * @notice Adds an amount to the PSM reserve for a specific reserve and DS.
     * @dev This function can only be called by the module core.
     * @param id The identifier of the reserve.
     * @param dsId The identifier of the DS.
     * @param amount The amount to add to the PSM reserve.
     */
    function addReservePsm(Id id, uint256 dsId, uint256 amount) external;

    /**
     * @notice empty all DS reserve to liquidity vault, can only be called by moduleCore
     * @dev this can only be called by the moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @return amount the amount that's emptied from Vault reserve
     */
    function emptyReserveLv(Id reserveId, uint256 dsId) external returns (uint256 amount);

    /**
     * @notice empty all DS reserve to PSM, can only be called by moduleCore
     * @dev this can only be called by the moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @return amount the amount that's emptied from PSM reserve
     */
    function emptyReservePsm(Id reserveId, uint256 dsId) external returns (uint256 amount);

    /**
     * @notice empty some or all DS reserve to PSM, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @param amount the amount of DS to empty
     * @return emptied emptied amount of DS that's emptied
     */
    function emptyReservePartialPsm(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 emptied);

    /**
     * @notice empty some or all DS reserve to liquidity vault, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @param amount the amount of DS to empty
     * @return emptied emptied amount of DS that's emptied
     */
    function emptyReservePartialLv(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 emptied);

    /**
     * @notice Executes a swap from RA to DS tokens.
     * @dev This function performs a flash swap, requiring a valid signature and deadline.
     * @param reserveId The ID of the reserve for RA:PA market in modulecore.
     * @param dsId The ID of the DS token to receive.
     * @param amount The amount of RA tokens to swap.
     * @param amountOutMin The minimum amount of DS tokens to receive.
     * @param params Additional parameters for the swap.
     * @param offchainGuess Offchain data used for the swap.
     * @return result The result of the swap, including amounts and other details.
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        BuyAprroxParams memory params,
        OffchainGuess memory offchainGuess
    ) external returns (SwapRaForDsReturn memory result);

    /**
     * @notice Executes a swap from RA to DS tokens.
     * @dev This function performs a flash swap, requiring a valid signature and deadline.
     * @param reserveId The ID of the reserve for RA:PA market in modulecore.
     * @param dsId The ID of the DS token to receive.
     * @param amount The amount of RA tokens to swap.
     * @param amountOutMin The minimum amount of DS tokens to receive.
     * @param rawRaPermitSig The raw signature for the RA permit.
     * @param deadline The deadline by which the swap must be completed.
     * @param params Additional parameters for the swap.
     * @param offchainGuess Offchain data used for the swap.
     * @return result The result of the swap, including amounts and other details.
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes memory rawRaPermitSig,
        uint256 deadline,
        BuyAprroxParams memory params,
        OffchainGuess memory offchainGuess
    ) external returns (SwapRaForDsReturn memory result);

    /**
     * @notice Swaps specified amount of DS tokens for RA tokens
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this.
     * @return amountOut amount of RA that's received
     * @dev Reverts if the actual amount is less than `amountOutMin`
     */
    function swapDsforRa(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        returns (uint256 amountOut);

    /**
     * @notice Swaps specified amount of DS tokens for RA tokens
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this.
     * @return amountOut amount of RA that's received
     * @dev Reverts if the actual amount is less than `amountOutMin`
     */
    function swapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Updates the discount rate in D days for the pair
     * @param id the pair id
     * @param discountRateInDays the new discount rate in D days
     * @dev only callable by the config contract
     */
    function updateDiscountRateInDdays(Id id, uint256 discountRateInDays) external;

    /**
     * @notice Updates the gradual sale status for a given reserve ID.
     * @dev This function can only be called by the contract configuration. If true, the reserve will try to sell DS tokens from the reserve gradually.
     * @param id The ID of the reserve to update.
     * @param status The new status to set for the gradual sale (true to disable, false to enable).
     */
    function updateGradualSaleStatus(Id id, bool status) external;

    /**
     * @notice Checks if the given reserve ID is in a rollover sale state.
     * @param id The ID of the reserve to check.
     * @return bool True if the reserve is in a rollover sale state, false otherwise.
     */
    function isRolloverSale(Id id) external view returns (bool);

    /**
     * @notice Updates the reserve sell pressure percentage for a specific reserve identified by `id`.
     * @dev This function can only be called by the config contract.
     * @param id The identifier of the reserve to update.
     * @param newPercentage The new reserve sell pressure percentage to be applied.
     */
    function updateReserveSellPressurePercentage(Id id, uint256 newPercentage) external;

    function sellPressureThreshold(Id id) external view returns (uint256);

    event DiscountRateUpdated(Id indexed id, uint256 discountRateInDays);

    event GradualSaleStatusUpdated(Id indexed id, bool disabled);

    event ReserveSellPressurePercentageUpdated(Id indexed id, uint256 newPercentage);

    event DsFeeUpdated(Id indexed id, uint256 newPercentage);

    event DsFeeTreasuryPercentageUpdated(Id indexed id, uint256 newPercentage);
}
