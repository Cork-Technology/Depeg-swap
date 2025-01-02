// SPDX-License-Identifier: BUSL-1.1
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
     * @param initialArp initial assets ARP. the initial ds price will be derived from this value. must be in 18 decimals(e.g 1% = 1e18)
     * @param psmBaseRedemptionFeePercentage base redemption fee for PSM, make sure it has 18 decimals(e.g 1% = 1e18)
     * @param expiryInterval expiry interval for DS, this will be used to calculate the next expiry time for DS(block.timestamp + expiryInterval)
     */
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 initialArp,
        uint256 psmBaseRedemptionFeePercentage,
        uint256 expiryInterval
    ) external;

    /**
     * @notice issue a new DS, can only be done after the previous DS has expired(if any). will deploy CT, DS and initialize new AMM and increment ds Id
     * @param id the id of the pair
     * @param exchangeRates the exchange rate of the DS, token that are non-rebasing MUST set this to 1e18, and rebasing tokens should set this to the current exchange rate in the market
     * @param repurchaseFeePercentage the repurchase fee for the DS, make sure it has 18 decimals(e.g 1% = 1e18)
     * @param decayDiscountRateInDays the decay discount rate in days, make sure it has 18 decimals(e.g 1% = 1e18)
     * @param rolloverPeriodInblocks the rollover sale period in blocks(e.g 500 means the rollover would happen right after this block until 500 blocks after the issuance block)
     */
    function issueNewDs(
        Id id,
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
     * @notice update pausing status of PSM Deposits
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     */
    function updatePsmDepositsStatus(
        Id id,
        bool isPSMDepositPaused
    ) external;

    /**
     * @notice update pausing status of PSM Withdrawals
     * @param id id of the pair
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     */
    function updatePsmWithdrawalsStatus(
        Id id,
        bool isPSMWithdrawalPaused
    ) external;

    /**
     * @notice update pausing status of PSM Repurchases
     * @param id id of the pair
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     */
    function updatePsmRepurchasesStatus(
        Id id,
        bool isPSMRepurchasePaused
    ) external;

    /**
     * @notice update pausing status of LV deposits
     * @param id id of the pair
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     */
    function updateLvDepositsStatus(
        Id id,
        bool isLVDepositPaused
    ) external;

    /**
     * @notice update pausing status of LV withdrawals
     * @param id id of the pair
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updateLvWithdrawalsStatus(
        Id id,
        bool isLVWithdrawalPaused
    ) external;

    /**
     * @notice update PSM base redemption fee percentage
     * @param newPsmBaseRedemptionFeePercentage new value of base redemption fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage) external;

    /**
     * @notice get next expiry time from id
     * @param id id of the pair
     * @return expiry next expiry time in seconds
     */
    function expiry(Id id) external view returns (uint256 expiry);
}
