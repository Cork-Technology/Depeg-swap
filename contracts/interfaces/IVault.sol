pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap-v2/RouterV2.sol";

/**
 * @title IVault Interface
 * @author Cork Team
 * @notice IVault interface for VaultCore contract
 */
interface IVault {
    struct Routers {
        IDsFlashSwapCore flashSwapRouter;
        IUniswapV2Router02 ammRouter;
    }

    struct PermitParams {
        bytes rawLvPermitSig;
        uint256 deadline;
    }

    struct RedeemEarlyParams {
        Id id;
        uint256 amount;
        uint256 amountOutMin;
        uint256 ammDeadline;
    }

    /// @notice Emitted when a user deposits assets into a given Vault
    /// @param id The Module id that is used to reference both psm and lv of a given pair
    /// @param depositor The address of the depositor
    /// @param amount  The amount of the asset deposited
    event LvDeposited(Id indexed id, address indexed depositor, uint256 amount);

    /// @notice Emitted when a user redeems Lv before expiry
    /// @param Id The Module id that is used to reference both psm and lv of a given pair
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the asset redeemed
    /// @param fee The total fee charged for early redemption
    /// @param feePercentage The fee percentage for early redemption, denominated in 1e18 (e.g 100e18 = 100%)
    event LvRedeemEarly(
        Id indexed Id,
        address indexed redeemer,
        uint256 amount,
        uint256 fee,
        uint256 feePercentage
    );

    /// @notice Emitted when a early redemption fee is updated for a given Vault
    /// @param Id The State id
    /// @param newEarlyRedemptionFee The new early redemption rate
    event EarlyRedemptionFeeUpdated(Id indexed Id, uint256 indexed newEarlyRedemptionFee);

    /// @notice caller is not authorized to perform the action, e.g transfering
    /// redemption rights to another address while not having the rights
    error Unauthorized(address caller);

    /// @notice inssuficient balance to perform expiry redeem(e.g requesting 5 LV to redeem but trying to redeem 10)
    error InsufficientBalance(address caller, uint256 requested, uint256 balance);

    /// @notice insufficient output amount, e.g trying to redeem 100 LV whcih you expect 100 RA but only received 50 RA
    error InsufficientOutputAmount(uint256 amountOutMin, uint256 received);

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     */
    function depositLv(Id id, uint256 amount, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received);

    /**
     * @notice Preview the amount of lv that will be deposited
     * @param amount The amount of the redemption asset(ra) to be deposited
     * @return lv The amount of lv that user will receive
     * @return raAddedAsLiquidity The amount of ra that will be added as liquidity, use this as a baseline for tolerance when adding depositing to LV
     * @return ctAddedAsLiquidity The amount of ct that will be added as liquidity, use this as a baseline for tolerance when adding depositing to LV
     */
    function previewLvDeposit(Id id, uint256 amount)
        external
        view
        returns (uint256 lv, uint256 raAddedAsLiquidity, uint256 ctAddedAsLiquidity);

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     * @param redeemer The address of the redeemer
     * @param permitParams The object with details for permit like rawLvPermitSig(Raw signature for LV approval permit) and deadline for signature
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams, address redeemer, PermitParams memory permitParams)
        external
        returns (uint256 received, uint256 fee, uint256 feePercentage, uint256 paAmount);


    /**
     * @notice preview redeem lv before expiry
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the asset to be redeemed
     */
    function previewRedeemEarlyLv(Id id, uint256 amount)
        external
        view
        returns (uint256 received, uint256 fee, uint256 feePercentage, uint256 paAmount);

    /**
     * Returns the early redemption fee percentage
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function earlyRedemptionFee(Id id) external view returns (uint256);

    /**
     * This will accure value for LV holders by providing liquidity to the AMM using the RA received from selling DS when a users buys DS
     * @param id the id of the pair
     * @param amount the amount of RA received from selling DS
     */
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external;

    /**
     * Returns the amount of AMM LP tokens that the vault holds
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function vaultLp(Id id) external view returns (uint256);

    function lvAcceptRolloverProfit(Id id, uint256 amount) external;
}
