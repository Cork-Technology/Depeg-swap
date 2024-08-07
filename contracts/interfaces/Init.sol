// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/Pair.sol";

interface Initialize {
    function initialize(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 lvAmmWaDepositThreshold,
        uint256 lvAmmCtDepositThreshold
    ) external;

    function issueNewDs(
        Id id,
        uint256 expiry,
        uint256 exchangeRates,
        uint256 repurchaseFeePrecentage
    ) external;

    function updateRepurchaseFeeRate(
        Id id,
        uint256 newRepurchaseFeePrecentage        
    ) external;

    function updateEarlyRedemptionFeeRate(
        Id id,
        uint256 newEarlyRedemptionFeeRate        
    ) external;
}
