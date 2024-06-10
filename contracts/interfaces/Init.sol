// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../libraries/Pair.sol";

interface Initialize {
    function initialize(
        address pa,
        address ra,
        address wa,
        address lv,
        uint256 lvFee,
        uint256 lvAmmWaDepositThreshold,
        uint256 lvAmmCtDepositThreshold
    ) external;

    function issueNewDs(Id id, uint256 expiry, address ct, address ds) external;
}
