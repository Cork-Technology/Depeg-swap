pragma solidity 0.8.24;

import {Id} from "../libraries/Pair.sol";

/**
 * @title Initialize Interface
 * @author Cork Team
 * @notice Initialize interface for providing Initialization related functions through ModuleCore contract
 */
interface Initialize {
    function initialize(address pa, address ra, uint256 lvFee, uint256 initialDsPrice) external;

    function issueNewDs(Id id, uint256 expiry, uint256 exchangeRates, uint256 repurchaseFeePrecentage) external;

    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePrecentage) external;

    function updateEarlyRedemptionFeeRate(Id id, uint256 newEarlyRedemptionFeeRate) external;

    function updatePoolsStatus(
        Id id,
        bool isPSMDepositPaused,
        bool isPSMWithdrawalPaused,
        bool isLVDepositPaused,
        bool isLVWithdrawalPaused
    ) external;

    function updatePsmBaseRedemptionFeePrecentage(uint256 newPsmBaseRedemptionFeePrecentage) external;
}
