// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Funder is AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IERC20 public cETH;
    IERC20 public cUSD;
    mapping(address => bool) public isFunded;

    error CallerNotManager();
    error InvalidUser();

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    constructor(address _cETH, address _cUSD) {
        cETH = IERC20(_cETH);
        cUSD = IERC20(_cUSD);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function fundUsers(address[] memory users, uint256 sepoliaAmt, uint256 cEthAmt, uint256 cUsdAmt)
        public
        onlyManager
    {
        uint256 length = users.length;
        cETH.transferFrom(msg.sender, address(this), cEthAmt * users.length);
        cUSD.transferFrom(msg.sender, address(this), cUsdAmt * users.length);
        for (uint256 i; i < length; ++i) {
            if (!isFunded[users[i]]) {
                if (cETH.balanceOf(users[i]) > 0 || cUSD.balanceOf(users[i]) > 0) {
                    revert InvalidUser();
                }
                payable(users[i]).transfer(sepoliaAmt);
                cETH.transfer(users[i], cEthAmt);
                cUSD.transfer(users[i], cUsdAmt);
                isFunded[users[i]] = true;
            }
        }
    }

    function fundEveryUsers(address[] memory users, uint256 sepoliaAmt, uint256 cEthAmt, uint256 cUsdAmt)
        public
        onlyManager
    {
        uint256 length = users.length;
        cETH.transferFrom(msg.sender, address(this), cEthAmt * users.length);
        cUSD.transferFrom(msg.sender, address(this), cUsdAmt * users.length);
        for (uint256 i; i < length; ++i) {
            if (cETH.balanceOf(users[i]) > 0 || cUSD.balanceOf(users[i]) > 0) {
                revert InvalidUser();
            }
            payable(users[i]).transfer(sepoliaAmt);
            cETH.transfer(users[i], cEthAmt);
            cUSD.transfer(users[i], cUsdAmt);
            isFunded[users[i]] = true;
        }
    }

    function withdrawETH() external onlyManager {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No Ether available to withdraw");
        payable(msg.sender).transfer(contractBalance);
    }

    receive() external payable {}
}
