// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CT Oracle contract
 * @author Cork Team
 * @notice CT Oracle contract for providing CT price
 */
contract CTOracle is Ownable {
    error ZeroAddress();

    /// @param _owner The owner of the CT Oracle contract
    constructor(address _owner) Ownable(_owner) {
        if (_owner == address(0)) {
            revert ZeroAddress();
        }
    }
}
