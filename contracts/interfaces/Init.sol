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
     * @param initialArp initial assets ARP. the initial ds price will be derived from this value. must be in 18 decimals(e.g 1% = 1e18)
     * @param expiryInterval expiry interval for DS, this will be used to calculate the next expiry time for DS(block.timestamp + expiryInterval)
     * @param exchangeRateProvider address of IExchangeRateProvider contract
     */
    function initializeModuleCore(address pa, address ra, uint256 initialArp, uint256 expiryInterval, address exchangeRateProvider) external;

    /**
     * @notice issue a new DS, can only be done after the previous DS has expired(if any). will deploy CT, DS and initialize new AMM and increment ds Id
     * @param id the id of the pair
     */
    function issueNewDs(
        Id id,
        uint256 decayDiscountRateInDays, // protocol-level config
        // won't have effect on first issuance
        uint256 rolloverPeriodInblocks, // protocol-level config
        uint256 ammLiquidationDeadline
    ) external;

    /**
     * @notice update PSM repurchase fee rate for a pair
     * @param id id of the pair
     * @param newRepurchaseFeePercentage new value of repurchase fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external;

    /**
     * @notice update pausing status of PSM Deposits
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     */
    function updatePsmDepositsStatus(Id id, bool isPSMDepositPaused) external;

    /**
     * @notice update pausing status of PSM Withdrawals
     * @param id id of the pair
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     */
    function updatePsmWithdrawalsStatus(Id id, bool isPSMWithdrawalPaused) external;

    /**
     * @notice update pausing status of PSM Repurchases
     * @param id id of the pair
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     */
    function updatePsmRepurchasesStatus(Id id, bool isPSMRepurchasePaused) external;

    /**
     * @notice update pausing status of LV deposits
     * @param id id of the pair
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     */
    function updateLvDepositsStatus(Id id, bool isLVDepositPaused) external;

    /**
     * @notice update pausing status of LV withdrawals
     * @param id id of the pair
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updateLvWithdrawalsStatus(Id id, bool isLVWithdrawalPaused) external;

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

    /**
     * @notice Get the last DS id issued for a given module, the returned DS doesn't guarantee to be active
     * @param id The current module id
     * @return dsId The current effective DS id
     *
     */
    function lastDsId(Id id) external view returns (uint256 dsId);

    /**
     * @notice returns the address of the underlying RA and PA token
     * @param id the id of PSM
     * @return ra address of the underlying RA token
     * @return pa address of the underlying PA token
     */
    function underlyingAsset(Id id) external view returns (address ra, address pa);

    /**
     * @notice returns the address of CT and DS associated with a certain DS id
     * @param id the id of PSM
     * @param dsId the DS id
     * @return ct address of the CT token
     * @return ds address of the DS token
     */
    function swapAsset(Id id, uint256 dsId) external view returns (address ct, address ds);

    function getId(address pa, address ra, uint256 initialArp, uint256 expiry, address exchangeRateProvider) external pure returns (Id);

    /// @notice Emitted when a new LV and PSM is initialized with a given pair
    /// @param id The PSM id
    /// @param pa The address of the pegged asset
    /// @param ra The address of the redemption asset
    /// @param lv The address of the LV
    /// @param expiry The expiry interval of the DS
    event InitializedModuleCore(Id indexed id, address indexed pa, address indexed ra, address lv, uint256 expiry);

    /// @notice Emitted when a new DS is issued for a given PSM
    /// @param id The PSM id
    /// @param dsId The DS id
    /// @param expiry The expiry of the DS
    /// @param ds The address of the DS token
    /// @param ct The address of the CT token
    /// @param raCtUniPairId The id of the uniswap-v4 pair between RA and CT
    event Issued(
        Id indexed id, uint256 indexed dsId, uint256 indexed expiry, address ds, address ct, bytes32 raCtUniPairId
    );
}
