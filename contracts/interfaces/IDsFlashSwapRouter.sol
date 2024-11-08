// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IUniswapV2Pair} from "./uniswap-v2/pair.sol";

/**
 * @title IDsFlashSwapUtility Interface
 * @author Cork Team
 * @notice Utility Interface for flashswap
 */
interface IDsFlashSwapUtility {
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
     * @notice returns the current reserve of the pair
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return raReserve reserve of RA
     * @return ctReserve reserve of CT
     */
    function getAmmReserve(Id id, uint256 dsId) external view returns (uint256 raReserve, uint256 ctReserve);

    /**
     * @notice returns the current DS reserve that is owned by liquidity vault
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return lvReserve reserve of DS
     */
    function getLvReserve(Id id, uint256 dsId) external view returns (uint256 lvReserve);

    /**
     * @notice returns the current DS reserve that is owned by PSM
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return psmReserve reserve of DS
     */
    function getPsmReserve(Id id, uint256 dsId) external view returns (uint256 psmReserve);

    /**
     * @notice returns the current cumulative HPA of the pair
     * @param id the id of the pair
     * @return hpaCummulative the current cumulative HPA
     */
    function getCurrentCumulativeHPA(Id id) external view returns (uint256 hpaCummulative);

    /**
     * @notice returns the current effective HPA of the pair
     * @param id the id of the pair
     */
    function getCurrentEffectiveHPA(Id id) external view returns (uint256 hpa);
}

/**
 * @title IDsFlashSwapCore Interface
 * @author Cork Team
 * @notice IDsFlashSwapCore interface for Flashswap Router contract
 */
interface IDsFlashSwapCore is IDsFlashSwapUtility {
    /// @notice thrown when output amount is not sufficient
    error InsufficientOutputAmount();

    /// @notice thrown when Permit is not supported in Given ERC20 contract
    error PermitNotSupported();

    /// @notice thrown when the caller is not the module core
    error NotModuleCore();

    /// @notice thrown when the caller is not Config contract
    error NotConfig();

    /// @notice thrown when the swap somehow got into rollover period, but the rollover period is not active
    error RolloverNotActive();

    error NotDefaultAdmin();

    /// @notice thrown when there's not enough liquidity to perform flash swap
    error InsufficientLiquidity(uint256 raReserve, uint256 ctReserve, uint256 amountRepayment);

    struct BuyAprroxParams {
        /// @dev the maximum amount of iterations to find the optimal amount of DS to swap
        uint256 maxApproxIter;
        /// @dev the amount that will be used to subtract borrowed amount to find the optimal amount for borrowing RA
        /// the lower the value, the more accurate the approximation will be but will be more expensive
        /// when in doubt use 0.01 ether or 1e16
        uint256 feeIntervalAdjustment;
        /// @dev the threshold tolerance that's used to find the optimal DS amount
        /// when in doubt use 1e9
        uint256 epsilon;
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
     */
    event RaSwapped(
        Id indexed reserveId, uint256 indexed dsId, address indexed user, uint256 amountIn, uint256 amountOut
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
     * @notice Emitted when some DS is swapped via rollover
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param user the user that's swapping
     * @param dsReceived the amount of DS that's received
     * @param raLeft the amount of RA that's left
     */
    event RolloverSold(
        Id indexed reserveId, uint256 indexed dsId, address indexed user, uint256 dsReceived, uint256 raLeft
    );

    /**
     * @notice trigger new issuance logic, can only be called my moduleCore
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
     * @notice add more DS reserve from liquidity vault, can only be called by moduleCore
     * @param id the pair id
     * @param dsId the ds id of the pair
     * @param amount the amount of DS to add
     */
    function addReserveLv(Id id, uint256 dsId, uint256 amount) external;

    function addReservePsm(Id id, uint256 dsId, uint256 amount) external;

    /**
     * @notice empty all DS reserve to liquidity vault, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @return amount the amount of DS that's emptied
     */
    function emptyReserveLv(Id reserveId, uint256 dsId) external returns (uint256 amount);

    function emptyReservePsm(Id reserveId, uint256 dsId) external returns (uint256 amount);

    function emptyReservePartialPsm(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 emptied);

    /**
     * @notice empty some or all DS reserve to liquidity vault, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @notice empty some or all DS reserve to liquidity vault, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @param amount the amount of DS to empty
     * @return emptied emptied amount of DS that's emptied
     */
    function emptyReservePartialLv(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 emptied);

    /**
     * @notice Swaps RA for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @param amountOutMin the minimum amount of DS to receive, will revert if the actual amount is less than this.
     * @return amountOut amount of DS that's received
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address user,
        bytes memory rawRaPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Swaps DS for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this.
     * @return amountOut amount of RA that's received
     */
    function swapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address user,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Updates the discount rate in D days for the pair
     * @param id the pair id
     * @param discountRateInDays the new discount rate in D days
     */
    function updateDiscountRateInDdays(Id id, uint256 discountRateInDays) external;

    /**
     * @notice update the gradual sale status, if true, will try to sell DS tokens from the reserve gradually
     */
    function updateGradualSaleStatus(Id id, bool status) external;

    function isRolloverSale(Id id, uint256 dsId) external view returns (bool);
}
