pragma solidity ^0.8.24;

import {Id} from "../libraries/Pair.sol";

/**
 * @title Initialize Interface
 * @author Cork Team
 * @notice Initialize interface for providing Initialization related functions through ModuleCore contract
 */
interface Initialize {
    /**
     * @notice initialize a new pool, this will initialize PSM and Liquidity Vault and deploy new LV token
     * @param pa address of PA token(e.g stETH)
     * @param ra address of RA token(e.g WETH)
     * @param lvFee fees for Liquidity Vault early withdrawal, make sure it has 18 decimals(e.g 1% = 1e18)
     * @param initialDsPrice initial target price of DS, will be used to derive optimal ratio to provide AMM from liquidity vault, make sure it has 18 decimals(e.g 0.1 = 1e17)
     *
     */
    function initializeModuleCore(address pa, address ra, uint256 lvFee, uint256 initialDsPrice, uint256 _psmBaseRedemptionFeePercentage) external;

    /**
     * @notice issue a new DS, can only be done after the previous DS has expired(if any). will deploy CT, DS and initialize new AMM and increment ds Id
     * @param id the id of the pair
     * @param expiry time in seconds after which the DS will expire
     * @param exchangeRates the exchange rate of the DS, token that are non-rebasing MUST set this to 1e18, and rebasing tokens should set this to the current exchange rate in the market
     * @param repurchaseFeePercentage the repurchase fee for the DS, make sure it has 18 decimals(e.g 1% = 1e18)
     * @param decayDiscountRateInDays the decay discount rate in days, make sure it has 18 decimals(e.g 1% = 1e18)
     * @param rolloverPeriodInblocks the rollover sale period in blocks(e.g 500 means the rollover would happen right after this block until 500 blocks after the issuance block)
     */
    function issueNewDs(
        Id id,
        uint256 expiry,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        // won't have effect on first issuance
        uint256 rolloverPeriodInblocks,
        uint256 ammLiquidationDeadline
    ) external;

    /**
     * @notice update PSM repurchase fee rate for a pair
     * @param id id of the pair
     * @param newRepurchaseFeePercentage new value of repurchase fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external;

    /**
     * @notice update liquidity vault early redemption fee rate for a pair
     * @param id id of the pair
     * @param newEarlyRedemptionFeeRate new value of earlyRedemptin fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateEarlyRedemptionFeeRate(Id id, uint256 newEarlyRedemptionFeeRate) external;

    /**
     * @notice update pausing status of PSM and LV pools
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updatePoolsStatus(
        Id id,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isPSMRepurchasePaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    ) external;

    /**
     * @notice update PSM base redemption fee percentage
     * @param newPsmBaseRedemptionFeePercentage new value of base redemption fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updatePsmBaseRedemptionFeePercentage(Id id,uint256 newPsmBaseRedemptionFeePercentage) external;
}
