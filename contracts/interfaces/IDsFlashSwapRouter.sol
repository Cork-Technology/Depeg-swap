pragma solidity 0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IUniswapV2Pair} from "./uniswap-v2/pair.sol";

/**
 * @title IDsFlashSwapUtility Interface
 * @author Cork Team
 * @notice Utility Interface for flashswap
 */
interface IDsFlashSwapUtility {
    function getCurrentPriceRatio(Id id, uint256 dsId)
        external
        view
        returns (uint256 raPriceRatio, uint256 ctPriceRatio);

    function getAmmReserve(Id id, uint256 dsId) external view returns (uint112 raReserve, uint112 ctReserve);

    function getLvReserve(Id id, uint256 dsId) external view returns (uint256 lvReserve);

    function getUniV2pair(Id id, uint256 dsId) external view returns (IUniswapV2Pair pair);
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
     * @param pair the RA:CT pair address
     * @param initialReserve the initial reserve of the DS, deposited by LV
     */
    event NewIssuance(Id indexed reserveId, uint256 indexed dsId, address ds, address pair, uint256 initialReserve);

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

    function onNewIssuance(
        Id reserveId,
        uint256 dsId,
        address ds,
        address pair,
        uint256 initialReserve,
        address ra,
        address ct
    ) external;

    function addReserve(Id id, uint256 dsId, uint256 amount) external;

    function emptyReserve(Id reserveId, uint256 dsId) external returns (uint256 amount);

    function emptyReservePartial(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 reserve);

    /**
     * @notice Swaps RA for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @param amountOutMin the minimum amount of DS to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapRaforDs
     * @return amountOut amount of DS that's received
     */
    function swapRaforDs(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        returns (uint256 amountOut);

    /**
     * @notice Preview the amount of DS that will be received from swapping RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @return amountOut amount of DS that will be received
     */
    function previewSwapRaforDs(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 amountOut);

    /**
     * @notice Swaps DS for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapDsforRa
     * @return amountOut amount of RA that's received
     */
    function swapDsforRa(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        returns (uint256 amountOut);

    /**
     * @notice Preview the amount of RA that will be received from swapping DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @return amountOut amount of RA that will be received
     */
    function previewSwapDsforRa(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 amountOut);
}
