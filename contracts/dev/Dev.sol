// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/dev/IDevToken.sol";

abstract contract Dev {
    function increase(address _contract, uint256 amount) external {
        IDevToken(_contract).mint(msg.sender, amount);
    }

    function decrease(address _contract, uint256 amount) external {
        IDevToken(_contract).burnSelf(amount);
    }
}
